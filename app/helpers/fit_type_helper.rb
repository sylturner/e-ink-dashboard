# Big type that steps down a size at a time until it fits its tile: a
# countdown's number, a rotation's entry. The sizes are render.css's type
# classes, so each step stays on the pixel grid. renders/_fit_type does
# the stepping once the fonts load, before the capture.
module FitTypeHelper
  TYPE_LADDER = %w[t-xxl t-xl t-lg t-md t-sm].freeze

  # Data attributes for an element drawn at one of TYPE_LADDER's sizes.
  def fit_type_data
    @fits_type = true
    { fit_type: TYPE_LADDER.join(" ") }
  end

  # Whether anything on the page asked to be fitted.
  def fits_type?
    @fits_type == true
  end
end
