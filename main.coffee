class Person extends Backbone.Model
  defaults:
    units: 'imperial'
    bmi: null

  unitMapping:
    height1:
      metric: 'm'
      imperial: 'ft'
      conversionFactor: 3.28084
    height2:
      metric: 'cm'
      imperial: 'in'
      conversionFactor: 0.393701
    weight:
      metric: 'kg'
      imperial: 'lbs'
      conversionFactor: 2.20462

  initialize: ->
    @on 'change:height1 change:height2', @calcHeight
    @on 'change:weight', @calcWeight
    @on 'change:metricWeight change:height', @calcBMI
    @on 'change:bmi change:age change:sex', @calcBF
    @on 'change:units', @adjustUnits
    @on 'change:weight change:bf', @calcLBM
    @on 'change:lbm', @calcBMR

    @adjustUnits @get('units')

    @recalc()

  recalc: ->
    @calcHeight()
    @calcWeight()

  adjustUnits: ->
    units = @get('units')
    for attr, val of @unitMapping
      @set "#{attr}_label", val[units]
      if @get(attr)?
        factor = if units is 'metric' then 1 / val.conversionFactor else val.conversionFactor
        @set attr, @get(attr) * factor

    @recalc()

  calcWeight: ->
    @set 'metricWeight', if @get('units') is 'metric' then @get('weight') else @get('weight') * 0.453592

  calcHeight: ->
    return unless @get('height1')?

    if @get('units') is 'metric'
      cm = @get('height2')
      m = @get('height1')
      height = if cm then ((+m * 100) + +cm) / 100 else m
    else
      ft = @get('height1')
      inches = @get('height2')
      height = ((+ft * 12) + +(inches or 0)) / 39.370

    @set 'height', height

  calcBMI: ->
    return null unless @get('metricWeight')? and @get('height')?

    bmi = (@get('metricWeight') / (@get('height') * @get('height'))).toFixed(2)
    @set 'bmi', bmi

    bmiLabel = switch
      when bmi < 15 then 'Very severely underweight'
      when bmi < 16 then 'Severely underweight'
      when bmi < 18.5 then 'Underweight'
      when bmi < 25 then 'Normal (healthy weight)'
      when bmi < 30 then 'Overweight'
      when bmi < 35 then 'Obese Class I (Moderately obese)'
      when bmi < 40 then 'Obese Class II (Severely obese)'
      else 'Obese Class III (Very severely obese'

    @set 'bmiDisplay', "#{bmi} (#{bmiLabel})"

  # Uses adult Deurenberg formula
  calcBF: ->
    return unless @get('bmi') and @get('age') and @get('sex')

    sexFactor = if @get('sex') is 'male' then 1 else 0
    bf = ((1.2 * +@get('bmi')) + (0.23 * @get('age')) - (10.8 * sexFactor) - 5.4).toFixed(2)
    @set 'bf', bf
    @set 'bfDisplay', "#{bf}%"

  calcLBM: ->
    return unless @get('weight') and @get('bf')

    lbm = (@get('weight') - @get('weight') * (@get('bf') / 100)).toFixed(2)
    @set 'lbm', lbm
    @set 'lbmDisplay', "#{lbm} #{@unitMapping.weight[@get('units')]}"

  calcBMR: ->
    return unless @get('lbm')

    lbm = if @get('units') is 'metric' then @get('lbm') else @get('lbm') * 0.453592

    bmr = Math.round(500 + 22 * lbm)
    @set 'bmr', bmr
    @set 'bmrDisplay', "#{bmr} calories"

class Measurements extends Backbone.View
  initialize: -> @render()

  render: ->
    (new Backbone.ModelBinder).bind @model, @el

results = [
  {
    id: "bmi"
    label: "BMI"
    requiredMeasurements: ["height", "weight"]
  },
  {
    id: "bf"
    label: "Estimated Body Fat"
    requiredMeasurements: ["height", "weight", "age", "sex"]
    notes: "Estimate based on the Deurenberg formula."
  },
  {
    id: "lbm"
    label: "Lean Body Mass"
    requiredMeasurements: ["height", "weight", "age", "sex"]
  }
  {
    id: "bmr"
    label: "Basal Metabolic Rate"
    requiredMeasurements: ["height", "weight", "age", "sex"]
    notes: "Based on the Cunningham formula."
  }
]

class Result extends Backbone.View
  template: '
    <div class="result">
      <label>{{label}}</label>
      {{#value}}<span>{{value}}</span>{{/value}}
      {{^value}}<p class="required-measurements">[Enter {{requiredMeasurements}}]</p>{{/value}}
      <p class="notes">{{notes}}</p>
    </div>
  '

  initialize: (params) ->
    @model.on 'change', => @render()
    @params = params

    @render()

  templateData: ->
    data = _.clone @params
    data.value = @model.get("#{@id}Display")
    data.requiredMeasurements = _.difference(@params.requiredMeasurements, _.keys(@model.attributes)).join ', '
    data

  render: ->
    @$el.html(Mustache.render @template, @templateData())

class Results extends Backbone.View
  initialize: -> @render()

  render: ->
    for result in results
      subview = new Result _.extend result, model: @model
      @$el.append subview.$el

person = new Person

$(document).ready ->
  new Measurements
    el: 'form'
    model: person

  new Results
    el: '#results'
    model: person

