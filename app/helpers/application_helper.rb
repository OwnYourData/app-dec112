module ApplicationHelper

    # Returns the full title on a per-page basis.
    def full_title(page_title = '')
        base_title = "OwnYourData"
        if page_title.empty?
            base_title
        else
            page_title + " | " + base_title
        end
    end

    def str2ascii(value)
        # https://stackoverflow.com/questions/1268289/how-to-get-rid-of-non-ascii-characters-in-ruby
        replacements = { 
            'á' => "a", 
            'à' => "a", 
            'é' => "e", 
            'è' => "e", 
            'ë' => 'e', 
            'í' => "i", 
            'ì' => "i", 
            'ú' => "u", 
            'ù' => "u", 
            "Ä" => "Ae", 
            "a" => "ae", 
            "Ö" => "Oe", 
            "ö" => "oe", 
            "Ü" => "Ue", 
            "ü" => "ue", 
            "ß" => "ss" }
        encoding_options = {
          :invalid   => :replace,     # Replace invalid byte sequences
          :replace => "",             # Use a blank for those replacements
          :universal_newline => true, # Always break lines with \n
          # For any character that isn't defined in ASCII, run this
          # code to find out how to replace it
          :fallback => lambda { |char|
            # If no replacement is specified, use an empty string
            replacements.fetch(char, "")
          },
      }
      return value.encode(Encoding.find('ASCII'), encoding_options)
    end

# Basis-Funktionen zum Zugriff auf PIA ====================
    # verwendete Header bei GET oder POST Requests
    def defaultHeaders(token)
      { 'Accept' => '*/*',
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer ' + token }
    end

    # URL beim Zugriff auf eine Repo
    def itemsUrl(url, repo_name)
      url + '/api/repos/' + repo_name + '/items'
    end

    # Anforderung eines Tokens für ein Plugin
    def getToken(pia_url, app_key, app_secret)
        auth_url = pia_url.to_s + "/oauth/token"
        response_nil = false
        begin
            response = HTTParty.post(auth_url, 
                headers: { 'Content-Type' => 'application/json' },
                body: { client_id: app_key, 
                    client_secret: app_secret, 
                    grant_type: "client_credentials" }.to_json )
        rescue => ex
            response_nil = true
        end
        if !response_nil && !response.body.nil? && response.code == 200
            response.parsed_response["access_token"].to_s
        else
            nil
        end
    end

    def decrypt_message(message, keyStr)
        begin
            cipher = [JSON.parse(message)["value"]].pack('H*')
            nonce = [JSON.parse(message)["nonce"]].pack('H*')
            keyHash = RbNaCl::Hash.sha256(keyStr.force_encoding('ASCII-8BIT'))
            private_key = RbNaCl::PrivateKey.new(keyHash)
            authHash = RbNaCl::Hash.sha256('auth'.force_encoding('ASCII-8BIT'))
            auth_key = RbNaCl::PrivateKey.new(authHash).public_key
            box = RbNaCl::Box.new(auth_key, private_key)
            val = box.decrypt(nonce, cipher)
            val            
        rescue
            nil
        end
    end

    # Hash mit allen App-Informationen zum Zugriff auf PIA
    def setupApp(pia_url, app_key, app_secret)
      token = getToken(pia_url, app_key, app_secret)
      { "pia_url"    => pia_url,
        "app_key"    => app_key,
        "app_secret" => app_secret,
        "token"      => token }
    end

    def getWriteKey(app, repo)
        headers = defaultHeaders(app["token"])
        repo_url = app["pia_url"] + '/api/repos/' + repo + '/pub_key'
        response = HTTParty.get(repo_url, headers: headers).parsed_response
        if response.key?("public_key")
            response["public_key"]
        else
            nil
        end
    end

    def getReadKey(app)
        headers = defaultHeaders(app["token"])
        user_url = app["pia_url"] + '/api/users/current'
        response = HTTParty.get(user_url, headers: headers).parsed_response
        if response.key?("password_key")
            decrypt_message(response["password_key"], app["password"])
        else
            nil
        end
    end

    # Lese und CRUD Operationen für ein Plugin (App) ==========
    # Daten aus PIA lesen
    def readRawItems(app, repo_url)
        headers = defaultHeaders(app["token"])
        url_data = repo_url + '?size=2000'
        response = HTTParty.get(url_data, headers: headers)
        response_parsed = response.parsed_response
        if response_parsed.nil? or 
                response_parsed == "" or
                response_parsed.include?("error")
            nil
        else
            recs = response.headers["total-count"].to_i
            if recs > 2000
                (2..(recs/2000.0).ceil).each_with_index do |page|
                    url_data = repo_url + '?page=' + page.to_s + '&size=2000'
                    subresp = HTTParty.get(url_data,
                        headers: headers).parsed_response
                    response_parsed = response_parsed + subresp
                end
                response_parsed
            else
                response_parsed
            end
        end
    end

    def oydDecrypt(app, repo_url, data)
        private_key = getReadKey(app)
        if private_key.nil?
            nil
        else
            response = []
            data.each do |item|
                retVal = decrypt_message(item.to_s, private_key)
                retVal = JSON.parse(retVal)
                retVal["id"] = JSON.parse(item)["id"]
                response << retVal
            end
            response
        end
    end

    def readItems(app, repo_url)
        if app.nil? || app == ""
            nil
        else
            respData = readRawItems(app, repo_url)
            if respData.nil?
                nil
            elsif respData.length == 0
                {}
            else
                data = JSON.parse(respData.first)
                if data.key?("version")
                    oydDecrypt(app, repo_url, respData)
                else
                    data
                end
            end
        end
    end

    def writeOydItem(app, repo_url, item)
        public_key_string = getWriteKey(app, "oyd.dec112")
        public_key = [public_key_string].pack('H*')
        authHash = RbNaCl::Hash.sha256('auth'.force_encoding('ASCII-8BIT'))
        auth_key = RbNaCl::PrivateKey.new(authHash)
        box = RbNaCl::Box.new(public_key, auth_key)
        nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
        message = item.to_json
        msg = message.force_encoding('ASCII-8BIT')
        cipher = box.encrypt(nonce, msg)
        oyd_item = { "value" => cipher.unpack('H*')[0],
                     "nonce" => nonce.unpack('H*')[0],
                     "version" => "0.4" }
        writeItem(app, repo_url, oyd_item)
    end

    # Daten in PIA schreiben
    def writeItem(app, repo_url, item)
      headers = defaultHeaders(app["token"])
      data = item.to_json
      response = HTTParty.post(repo_url,
                               headers: headers,
                               body: data)
      response
    end

    # Daten in PIA aktualisieren
    def updateItem(app, repo_url, item, id)
      headers = defaultHeaders(app["token"])
      response = HTTParty.put(repo_url + "/" + id.to_s,
                               headers: headers,
                               body: item.to_json)
      response    
    end

    # Daten in PIA löschen
    def deleteItem(app, repo_url, id)
      headers = defaultHeaders(app["token"])
      url = repo_url + '/' + id.to_s
      response = HTTParty.delete(url,
                                 headers: headers)
      # puts "Response: " + response.to_s
      response
    end

    # alle Daten einer Liste (Repo) löschen
    def deleteRepo(app, repo_url)
      allItems = readItems(app, repo_url)
      if !allItems.nil?
        allItems.each do |item|
          deleteItem(app, repo_url, item["id"])
        end
      end
    end

    def pia_connect(params)
        pia_url = params[:PIA_URL].to_s
        if pia_url.to_s == ""
            pia_url = session[:pia_url]
            if pia_url.to_s == ""
                pia_url = cookies.signed[:pia_url]
            end
        else
            session[:pia_url] = pia_url
        end

        app_key = params[:APP_KEY].to_s
        if app_key.to_s == ""
            app_key = session[:app_key]
            if app_key.to_s == ""
                app_key = cookies.signed[:app_key]
            end
        else
            session[:app_key] = app_key
        end

        app_secret = params[:APP_SECRET].to_s
        if app_secret.to_s == ""
            app_secret = session[:app_secret]
            if app_secret.to_s == ""
                app_secret = cookies.signed[:app_secret]
            end
        else
            session[:app_secret] = app_secret
        end

        desktop = params[:desktop].to_s
        if desktop == ""
            desktop = session[:desktop]
            if desktop == ""
                desktop = false
            else
                if desktop == "1"
                    desktop = true
                else
                    desktop = false
                end
            end
        else
            if desktop == "1"
                desktop = true
            else
                desktop = false
            end
        end
        if desktop
            session[:desktop] = "1"
        else
            session[:desktop] = "0"
        end

        nonce = params[:NONCE].to_s
        if nonce.to_s == ""
            nonce = session[:nonce].to_s
            if nonce.to_s == ""
                nonce = cookies.signed[:nonce].to_s
            end
        else
            session[:nonce] = nonce
        end

        master_key = params[:MASTER_KEY].to_s
        if master_key.to_s == ""
            master_key = session[:master_key].to_s
            if master_key.to_s == ""
                master_key = cookies.signed[:master_key].to_s
                if master_key == ""
                    nonce = ""
                end
            end
        else
            session[:master_key] = master_key
        end

        password = ""
        if nonce != ""
            begin
                # get cipher
                nonce_url = pia_url + '/api/support/' + nonce
                response = HTTParty.get(nonce_url)
                if response.code == 200
                    cipher = response.parsed_response["cipher"]
                    cipherHex = [cipher].pack('H*')
                    nonceHex = [nonce].pack('H*')
                    keyHash = [master_key].pack('H*')
                    private_key = RbNaCl::PrivateKey.new(keyHash)
                    authHash = RbNaCl::Hash.sha256('auth'.force_encoding('ASCII-8BIT'))
                    auth_key = RbNaCl::PrivateKey.new(authHash).public_key
                    box = RbNaCl::Box.new(auth_key, private_key)
                    password = box.decrypt(nonceHex, cipherHex)

                    # write to cookies in any case if NONCE is provided in URL
                    cookies.permanent.signed[:pia_url] = pia_url
                    cookies.permanent.signed[:app_key] = app_key
                    cookies.permanent.signed[:app_secret] = app_secret
                    cookies.permanent.signed[:password] = password

                end
            rescue
                
            end
        end
        if params[:password].to_s != ""
            password = params[:password].to_s
        end
        cookie_password = false
        if password.to_s == ""
            password = session[:password].to_s
            if password.to_s == ""
                password = cookies.signed[:password]
                if password.to_s != ""
                    cookie_password = true
                end
            end
        else
            session[:password] = password
            if params[:remember].to_s == "1"
                cookies.permanent.signed[:pia_url] = pia_url
                cookies.permanent.signed[:app_key] = app_key
                cookies.permanent.signed[:app_secret] = app_secret
                cookies.permanent.signed[:password] = password
            end
        end
        @pia_url = pia_url
        @app_key = app_key
        @app_secret = app_secret

        # puts "pia_url: " + pia_url.to_s
        # puts "app_key: " + app_key.to_s
        # puts "app_secret: " + app_secret.to_s
        # puts "password: " + password.to_s

        token = getToken(pia_url, app_key, app_secret).to_s
        if token == ""
            redirect_to error_path(pia_url: pia_url)
            return
        end
        session[:token] = token
        # puts "token: " + token.to_s

        if password.to_s == ""
            redirect_to password_path(pia_url: pia_url)
            return
        end

        app = setupApp(pia_url, app_key, app_secret)
        app["password"] = password.to_s
        if getReadKey(app).nil?
            if cookie_password
                flash[:warning] = t('general.wrongCookiePassword')
            else
                flash[:warning] = t('general.wrongPassword')
            end
            redirect_to password_path(pia_url: pia_url, app_key: app_key, app_secret: app_secret)
            return
        end

        if app.nil?
            redirect_to password_path(pia_url: pia_url, app_key: app_key, app_secret: app_secret)
            return
        end
        app
    end

end
