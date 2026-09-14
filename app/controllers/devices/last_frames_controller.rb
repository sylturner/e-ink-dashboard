class Devices::LastFramesController < ApplicationController
  include LastFrame

  # GET /devices/1/last_frame
  #
  # The newest bitmap a panel was sent, for its card and page. Unlike
  # FramesController, which the panel itself calls, it records no
  # check-in and never composes a frame.
  def show
    send_last_frame(Device.find(params.expect(:device_id)).frames)
  end
end
