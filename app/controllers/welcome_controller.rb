require 'digest'
require 'open-uri'
require "base64"
class WelcomeController < ApplicationController
  def index
  end

  def detect
    found = false

    authenticity_code = params[:authenticity_code]

    # convert authenticity code to sha512
    authenticity_code_sha512 = Digest::SHA512.hexdigest authenticity_code
    authenticity_code_sha512_array = authenticity_code_sha512.scan(/...../)

    padding_string = "0"

    for i in 0..(authenticity_code_sha512_array.size - 1)
      authenticity_code_sha512_array[i] = authenticity_code_sha512_array[i] + (padding_string * 27)
    end
    # authenticity_code_sha512_array now contains the AN

    serial_number = 12345
    coin_denomination = 0

    case serial_number
      when 1..2097152 then coin_denomination = 1
      when 2097153..4194304 then coin_denomination = 5
      when 4194305..6291456 then coin_denomination = 25
      when 6291457..14680064 then coin_denomination = 100
      when 14680065..16777217 then coin_denomination = 250
    end

    pass_count = 0
    # Detect Request from RAIDA
    for i in 0..(authenticity_code_sha512_array.size - 1)
      url_string = "https://RAIDA" + i.to_s + ".cloudcoin.global/service/detect?nn=1&sn=" + serial_number.to_s + "&an=" + authenticity_code_sha512_array[i] + "&pan=" + authenticity_code_sha512_array[i] + "&denomination=" + coin_denomination.to_s
      puts url_string
      response = open(url_string).read
      puts response
      response_JSON = JSON.parse(response)
      if (response_JSON["status"] == "pass")
        pass_count = pass_count + 1
      end
    end

    message = ""
    if (pass_count < 20)
      redirect_to index_path, alert: "Authentication numbers did not match"
      return
    else
      url_string = "https://raida18.cloudcoin.global/service/get_ticket?nn=1&sn=" + serial_number.to_s + "&an=" + authenticity_code_sha512_array[18] + "&pan=" + authenticity_code_sha512_array[18] + "&denomination=" + coin_denomination.to_s
      response = open(url_string).read
      response_JSON = JSON.parse(response)
      message = response_JSON["message"]

      url_string = "https://raida.tech/get_template.php?nn=1&sn=" + serial_number.to_s + "&fromserver1=18&message1=" + message
      response = open(url_string).read
      response_JSON = JSON.parse(response)
      jpeg_base64_string = response_JSON["jpeg"]
      title = response_JSON["meta"]["title"]
      description = response_JSON["meta"]["description"]
      short_description = response_JSON["meta"]["short_description"]

      full_image_name = Rails.root.join('public', 'jpeg_server_images')
      # save image from base64 to disk
      File.open(message + ".jpeg", 'wb') do |f|
        f.write(Base64.decode64(jpeg_base64_string))
      end
    end


    if (found)
      puts "*****hello****"
    else
      puts "Not found"
      redirect_to index_path, alert: "Not found"
    end
  end

  def show
  end
end
