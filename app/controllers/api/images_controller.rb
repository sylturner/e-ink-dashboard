# GET /api/images/1.bmp
#
# The image a check-in pointed a panel at. It only reads: the frame was
# composed during the check-in.
class Api::ImagesController < Api::BaseController
  def show
    frame = Frame.rendered.find_by(id: params.expect(:id))
    return head(:not_found) if frame.nil?

    send_data frame.data, type: frame.content_type, disposition: "inline"
  end
end
