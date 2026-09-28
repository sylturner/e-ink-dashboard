require "test_helper"

class WifiNetworkTest < ActiveSupport::TestCase
  test "writes a network as the text phones join from" do
    assert_equal "WIFI:T:WPA;S:Home;P:hunter22;;", WifiNetwork.new(ssid: "Home", password: "hunter22").to_s
  end

  test "an open network has no password, and a hidden one says so" do
    network = WifiNetwork.new(ssid: "Cafe", password: "ignored", security: "nopass", hidden: "1")

    assert_equal "WIFI:T:nopass;S:Cafe;H:true;;", network.to_s
    assert network.open?
  end

  test "escapes the characters the format uses" do
    network = WifiNetwork.new(ssid: %(My "Net"; 2), password: 'a\b,c:d', security: "WEP")

    assert_equal 'WIFI:T:WEP;S:My \"Net\"\; 2;P:a\\\\b\,c\:d;;', network.to_s
  end

  test "needs a name, and takes an unknown security as WPA" do
    assert_not WifiNetwork.new(ssid: "").valid?
    assert_equal "WPA", WifiNetwork.new(ssid: "Home", security: "WPA9").security
    assert_not WifiNetwork.new(ssid: "Home", hidden: "0").hidden?
  end
end
