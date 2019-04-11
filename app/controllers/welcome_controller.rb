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
    # divide sha512 to 25 substrings and store them in an array
    authenticity_code_sha512_array = authenticity_code_sha512.scan(/...../)

    padding_string = "0"
    # padding the 25 substrings with 0s. Each string will be 32 characters of the form:
    #   xxxxx00000000000000000000000000000000
    for i in 0..24
      authenticity_code_sha512_array[i] = authenticity_code_sha512_array[i] + (padding_string * 27)
    end
    # authenticity_code_sha512_array now contains the AN

    serial_number = 1346931
    coin_denomination = 0

    # determine coin denomination based on serial number
    case serial_number
      when 1..2097152 then coin_denomination = 1
      when 2097153..4194304 then coin_denomination = 5
      when 4194305..6291456 then coin_denomination = 25
      when 6291457..14680064 then coin_denomination = 100
      when 14680065..16777217 then coin_denomination = 250
    end

    pass_count = 0
    # Detect Request from RAIDA

    threads = []
    25.times do |i|
      threads[i] = Thread.new {
        url_string = "https://RAIDA" + i.to_s + ".cloudcoin.global/service/detect?nn=1&sn=" + serial_number.to_s + "&an=" + authenticity_code_sha512_array[i] + "&pan=" + authenticity_code_sha512_array[i] + "&denomination=" + coin_denomination.to_s
        puts url_string
        response = open(url_string).read
        puts response
        response_JSON = JSON.parse(response)
        if (response_JSON["status"] == "pass")
          Thread.current["pass"] = true
        end
      }
    end
    threads.each { |t|
      t.join
      if (t["pass"] == true)
        pass_count += 1
      end
    }
    puts "pass_count = " + pass_count.to_s

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

      relative_image_name = "public/jpeg_server/" + message + ".jpeg"
      # save image from base64 to disk
      File.open(relative_image_name, 'wb') do |f|
        f.write(Base64.decode64(jpeg_base64_string))
      end

      redirect_to controller: :welcome,
        action: :show,
        image_path: "jpeg_server/" + message + ".jpeg",
        image_title: title,
        image_description: description,
        image_short_description: short_description,
        flash: {success: "Product is authentic!"}
      # redirect_to show_path, success: "Product is authentic!", image_path: 
      return
    end
  end

  def show
    @image_path = params[:image_path]
    @image_title = params[:image_title]
    @image_description = params[:image_description]
    @image_short_description = params[:image_short_description]
  end
end
