class PagesController < ApplicationController
	include ApplicationHelper

	def index
		start_ts = Time.now.to_i
		app = pia_connect(params)
		if !app.nil?
	        if request.post?
	            redirect_to root_path
	        end

			dec_url = itemsUrl(app["pia_url"], "oyd.dec112")
			dec_data = readItems(app, dec_url)

puts dec_data.to_json
puts dec_data.length

			@dec_raw = "not available"
			if !dec_data.nil? && dec_data.length > 0
				@dec_raw = JSON.pretty_generate(dec_data.first) rescue "not available"
				@title = dec_data.first["title"] rescue ""
				@firstname = dec_data.first["surName"] rescue ""
				@lastname = dec_data.first["familyName"] rescue ""
				@address = dec_data.first["street"] rescue ""
				@zip_code = dec_data.first["zipCode"] rescue ""
				@city = dec_data.first["city"] rescue ""
				@mail = dec_data.first["mail"] rescue ""
			end
		end

	end

	def write
		app = pia_connect(params)	
		dec_url = itemsUrl(app["pia_url"], "oyd.dec112")
		raw_data = readRawItems(app, dec_url).first rescue []
		raw_item = JSON.parse(raw_data)
		id = raw_item["id"]
		dec_data = readItems(app, dec_url).first rescue []

		dec_data["title"] = params[:title].to_s
		dec_data["surName"] = params[:firstname].to_s
		dec_data["familyName"] = params[:lastname].to_s
		dec_data["street"] = params[:address].to_s
		dec_data["zipCode"] = params[:zip_code].to_s
		dec_data["city"] = params[:city].to_s
		dec_data["mail"] = params[:mail].to_s

        public_key_string = getWriteKey(app, "oyd.dec112")
        public_key = [public_key_string].pack('H*')
        authHash = RbNaCl::Hash.sha256('auth'.force_encoding('ASCII-8BIT'))
        auth_key = RbNaCl::PrivateKey.new(authHash)
        box = RbNaCl::Box.new(public_key, auth_key)
        nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
        message = dec_data.to_json
        msg = message.force_encoding('ASCII-8BIT')
        cipher = box.encrypt(nonce, msg)
        oyd_item = { "value" => cipher.unpack('H*')[0],
                     "nonce" => nonce.unpack('H*')[0],
                     "version" => "0.4",
                     "key1" => raw_item["key1"].to_s,
                     "id" =>  id}
        retVal = updateItem(app, dec_url, oyd_item, id)

		redirect_to root_path
		return
	end

	def error
		@pia_url = params[:pia_url]
	end

	def password
		@pia_url = params[:pia_url]
		@app_key = params[:app_key]
		@app_secret = params[:app_secret]
	end

	def favicon
		send_file 'public/favicon.ico', type: 'image/x-icon', disposition: 'inline'
	end
	
end
