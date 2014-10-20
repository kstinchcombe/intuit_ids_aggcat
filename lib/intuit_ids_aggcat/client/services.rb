require 'oauth'
require 'rexml/document'
require 'xml/mapping'
require 'intuit_ids_aggcat/client/intuit_xml_mappings'

module IntuitIdsAggcat

  module Client
    
    class Services

      cattr_accessor :verbose

      class << self

        def initialize
          
        end

        # adds Services#stub_with(xml, response_code) method
        def enable_stubbing
          require 'intuit_ids_aggcat/client/services_stub'
        end

        ##
        # Gets all institutions supported by Intuit. If oauth_token_info isn't provided, new tokens are provisioned using "default" user
        # consumer_key and consumer_secret will be retrieved from the Configuration class if not provided
        def get_institutions oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens("default"), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          response = oauth_get_request "https://financialdatafeed.platform.intuit.com/rest-war/v1/institutions", oauth_token_info, consumer_key, consumer_secret
          if response[:response_code] == "200"
            institutions = Institutions.load_from_xml(response[:response_xml].root)
            institutions.institutions
          else
            return nil
          end
        end

        ##
        # Gets the institution details for id. If oauth_token_info isn't provided, new tokens are provisioned using "default" user
        # consumer_key and consumer_secret will be retrieved from the Configuration class if not provided
        def get_institution_detail id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens("default"), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          response = oauth_get_request "https://financialdatafeed.platform.intuit.com/rest-war/v1/institutions/#{id}", oauth_token_info, consumer_key, consumer_secret
          institutions = InstitutionDetail.load_from_xml(response[:response_xml].root)
          institutions
        end

        ##
        # Get a specific account for a customer from aggregation at Intuit.
        # username and account ID must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def get_account username, account_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/accounts/#{account_id}"
          response = oauth_get_request url, oauth_token_info
          account = AccountList.load_from_xml(response[:response_xml].root)
        end


        ##
        # Deletes the customer's accounts from aggregation at Intuit.
        # username must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def delete_customer username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/customers/"
          oauth_delete_request url, oauth_token_info
        end

        ##
        # Deletes the a specific account for a customer from aggregation at Intuit.
        # username and account ID must be provided, if no oauth_token_info is provided, new tokens will be provisioned using username
        def delete_account username, account_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          puts "in gem, username = #{username}, account = #{account_id}."
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/accounts/#{account_id}"
          oauth_delete_request url, oauth_token_info
        end

        ##
        # Discovers and adds accounts using credentials
        # institution_id is the ID of the institution, username is the ID for this customer's accounts at Intuit and must be used for future requests,
        # creds_hash is a hash object of key value pairs used for authentication
        # If oauth_token is not provided, new tokens will be provisioned using the username provided
        # Returns a hash produced by discover_account_data_to_hash with the following keys:
        #    discover_response   : hash including the following keys:
        #                              response_code:        HTTP response code from Intuit
        #                              response_xml :        XML returned by Intuit
        #    accounts            : Ruby hash with accounts if returned by discover call
        #    challenge_type      : text description of the type of challenge requested, if applicable
        #                          "none" | "choice" | "image" | "text" 
        #    challenge           : Ruby hash with the detail of the challenge if applicable
        #    challenge_session_id: challenge session ID to pass to challenge_response if this is a challenge
        #    challenge_node_id   : challenge node ID to pass to challenge_response if this is a challenge 
        #    description         : text description of the result of the discover request

        def discover_and_add_accounts_with_credentials institution_id, username, creds_hash, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 30

          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/institutions/#{institution_id}/logins"
          credentials_array = []
          creds_hash.each do |k,v|
            c = Credential.new
            c.name = k
            c.value = v
            credentials_array.push c
          end
          creds = Credentials.new
          creds.credential = credentials_array
          il = InstitutionLogin.new
          il.credentials = creds
          daa = oauth_post_request url, oauth_token_info, il.save_to_xml.to_s
          discover_account_data_to_hash daa
        end

        ##
        # Given a username, response text, challenge session ID and challenge node ID, passes the credentials to Intuit to begin aggregation
        def challenge_response institution_id, username, response, challenge_session_id, challenge_node_id, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/institutions/#{institution_id}/logins"
          if !(response.kind_of?(Array) || response.respond_to?('each'))
            response = [response]
          end

          cr = IntuitIdsAggcat::ChallengeResponses.new
          cr.response = response
          il = IntuitIdsAggcat::InstitutionLogin.new
          il.challenge_responses = cr
          daa = oauth_post_request url, oauth_token_info, il.save_to_xml.to_s, { "challengeSessionId" => challenge_session_id, "challengeNodeId" => challenge_node_id }
          discover_account_data_to_hash daa
        end

        ##
        # Gets all accounts for a customer
        def get_customer_accounts username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/accounts/"
          response = oauth_get_request url, oauth_token_info
          accounts = AccountList.load_from_xml(response[:response_xml].root)
        end

        ##
        # Gets accounts for a specific customer login_id
        def get_login_accounts login_id, username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/logins/#{login_id}/accounts"
          response = oauth_get_request url, oauth_token_info
          accounts = AccountList.load_from_xml(response[:response_xml].root)
        end

        ##
        # Updates an existing customer account with new credentials at an institution
        # Response can include an MFA challenge; see the return values for discover_and_add_accounts_with_credentials for
        # more information on possible responses
        def update_institution_login_with_credentials login_id, username, creds_hash, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/logins/#{login_id}?refresh=true"
          credentials_array = []
          creds_hash.each do |k,v|
            c = Credential.new
            c.name = k
            c.value = v
            credentials_array.push c
          end
          creds = Credentials.new
          creds.credential = credentials_array
          il = InstitutionLogin.new
          il.credentials = creds
          response = oauth_put_request url, oauth_token_info, il.save_to_xml.to_s
          update_credentials_data_to_hash response
        end

        ##
        # Explicitly refreshes the customer account with new credentials at an institution
        def update_institution_login_explicit_refresh login_id, username, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          url = "https://financialdatafeed.platform.intuit.com/v1/logins/#{login_id}?refresh=true"
          body = InstitutionLogin.new.save_to_xml.to_s
          response = oauth_put_request url, oauth_token_info, body
          return response
        end

        ##
        # Get transactions for a specific account and timeframe
        def get_account_transactions username, account_id, start_date, end_date = nil, oauth_token_info = IntuitIdsAggcat::Client::Saml.get_tokens(username), consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret
          txn_start = start_date.strftime("%Y-%m-%d")
          url = "https://financialdatafeed.platform.intuit.com/rest-war/v1/accounts/#{account_id}/transactions?txnStartDate=#{txn_start}"
          if !end_date.nil?
            txn_end = end_date.strftime("%Y-%m-%d")
            url = "#{url}&txnEndDate=#{txn_end}"
          end
          response = oauth_get_request url, oauth_token_info
          xml = REXML::Document.new response[:response_xml].to_s
          tl = IntuitIdsAggcat::TransactionList.load_from_xml xml.root
        end

        ## 
        # Helper method for parsing discover credential update response data
        def update_credentials_data_to_hash daa
          challenge_type = "none"
          if daa[:response_code] == "200"
            # return account list
            accounts = AccountList.load_from_xml(daa[:response_xml].root)
            { update_response: daa, challenge_type: challenge_type, challenge: nil, description: "Account information updated." }
          elsif daa[:response_code] == "401" && daa[:challenge_session_id]
            # return challenge
            challenge = Challenges.load_from_xml(daa[:response_xml].root)
            challenge_type = "unknown"
            if challenge.save_to_xml.to_s.include?("<choice>")
              challenge_type = "choice"
            elsif challenge.save_to_xml.to_s.include?("image")
              challenge_type ="image"
            else
              challenge_type = "text"
            end
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: challenge, challenge_session_id: daa[:challenge_session_id], challenge_node_id: daa[:challenge_node_id], description: "Multi-factor authentication required to update credentials." }
          elsif daa[:response_code] == "404"
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Login ID not found." }
          elsif daa[:response_code] == "408"
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Timed out." }
          elsif daa[:response_code] == "500"
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Internal server error." }
          elsif daa[:response_code] == "503"
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Problem at the financial institution." }
          else
            { update_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Unknown error." }
          end
        end

        ## 
        # Helper method for parsing discover account response data
        def discover_account_data_to_hash daa
          challenge_type = "none"
          if daa[:response_code] == "201"
            # return account list
            accounts = AccountList.load_from_xml(daa[:response_xml].root)
            { discover_response: daa, accounts: accounts, challenge_type: challenge_type, challenge: nil, description: "Account information retrieved." }
          elsif daa[:response_code] == "401" && daa[:challenge_session_id]
            # return challenge
            challenge = Challenges.load_from_xml(daa[:response_xml].root)
            challenge_type = "unknown"
            if challenge.save_to_xml.to_s.include?("<choice>")
              challenge_type = "choice"
            elsif challenge.save_to_xml.to_s.include?("image")
              challenge_type ="image"
            else
              challenge_type = "text"
            end
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: challenge, challenge_session_id: daa[:challenge_session_id], challenge_node_id: daa[:challenge_node_id], description: "Multi-factor authentication required to retrieve accounts." }
          elsif daa[:response_code] == "404"
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Institution not found." }
          elsif daa[:response_code] == "408"
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Multi-factor authentication session expired." }
          elsif daa[:response_code] == "500"
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Internal server error." }
          elsif daa[:response_code] == "503"
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Problem at the financial institution." }
          else
            { discover_response: daa, accounts: nil, challenge_type: challenge_type, challenge: nil, description: "Unknown error." }
          end
        end

        ##
        # Helper method to issue post requests
        # KS 10/20/14 - compatibility note: I reordered oauth_token_info, body args to standardize with how the other functions are called
        def oauth_post_request url, oauth_token_info, body, headers = {}, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 120
          response_code, response_xml, response = oauth_request 'post', url, oauth_token_info, body, headers, consumer_key, consumer_secret, timeout

          # handle challenge responses from discoverAndAcccounts flow
          challenge_session_id = challenge_node_id = nil
          if !response["challengeSessionId"].nil?
            challenge_session_id = response["challengeSessionId"]
            challenge_node_id = response["challengeNodeId"]
          end

          { :challenge_session_id => challenge_session_id, :challenge_node_id => challenge_node_id, :response_code => response_code, :response_xml => response_xml }
        end

        ##
        # Helper method to issue get requests
        def oauth_get_request url, oauth_token_info, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 120
          response_code, response_xml = oauth_request 'get', url, oauth_token_info, nil, nil, consumer_key, consumer_secret, timeout
          { :response_code => response_code, :response_xml => response_xml }
        end

        ##
        # Helper method to issue put requests
        def oauth_put_request url, oauth_token_info, body = nil, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 120
          response_code, response_xml = oauth_request 'put', url, oauth_token_info, body, nil, consumer_key, consumer_secret, timeout
          { :response_code => response_code, :response_xml => response_xml }
        end

        ##
        # Helper method to issue delete requests
        def oauth_delete_request url, oauth_token_info, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 120
          response_code, response_xml = oauth_request 'delete', url, oauth_token_info, nil, nil, consumer_key, consumer_secret, timeout
          { :response_code => response_code, :response_xml => response_xml }
        end

        ##
        # Helper method for api requests
        # http_method in get / post / put / delete
        # will return response_xml=nil if there is an XML parse exception
        def oauth_request http_method, url, oauth_token_info, body = nil, headers = {}, consumer_key = IntuitIdsAggcat.config.oauth_consumer_key, consumer_secret = IntuitIdsAggcat.config.oauth_consumer_secret, timeout = 120

          headers ||= {}
          http_method = http_method.to_s
          p "Intuit #{http_method.upcase} request: url #{url}" if verbose

          # gather our http options
          options = { :request_token_path => 'https://financialdatafeed.platform.intuit.com', :timeout => timeout }
          options = options.merge(:http_method => :put) if http_method == 'put'  # KS 10/20/14 - no idea why this is here
          options = options.merge({ :proxy => IntuitIdsAggcat.config.proxy}) if !IntuitIdsAggcat.config.proxy.nil?

          # set up our oauth access token
          oauth_token = oauth_token_info[:oauth_token]
          oauth_token_secret = oauth_token_info[:oauth_token_secret]
          consumer = OAuth::Consumer.new(consumer_key, consumer_secret, options)
          access_token = get_access_token(consumer, oauth_token, oauth_token_secret)

          # fetch and parse our API response
          headers = headers.merge( "Content-Type"=>'application/xml', 'Host' => 'financialdatafeed.platform.intuit.com' )
          if http_method == 'post' || http_method == 'put' # send body on post and put requests
            response = access_token.send(http_method.to_sym, url, body, headers)
          else
            response = access_token.send(http_method.to_sym, url, headers)
          end
          # if the response is unparseable, dump it and re-raise the exception
          begin
            p "Intuit response: code #{response.code}, document\n\n#{response.body}\n\n" if verbose
            response_xml = REXML::Document.new response.body
          rescue REXML::ParseException => ex
            p "Intuit API REXML Parse Exception: #{ex}"
            p(response.body) unless verbose
            raise ex
          end

          return response.code, response_xml, response
        end

        # we break this out so we can stub it to simulate XML responses in testing
        def get_access_token consumer, oauth_token, oauth_token_secret
          OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
        end
    
      end
    end
  end
end
