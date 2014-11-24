# usage:
#
#  # simulate getting details for Carolina Foothills FCU Credit Card
#  IntuitIdsAggcat::Client::Services.stub_with("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><InstitutionDetail xmlns=\"http://schema.intuit.com/platform/fdatafeed/institution/v1\" xmlns:ns2=\"http://schema.intuit.com/platform/fdatafeed/common/v1\"><institutionId>8860</institutionId><institutionName>Carolina Foothills FCU Credit Card</institutionName><homeUrl>http://www.cffcu.org/index.html</homeUrl><phoneNumber>1-864-585-6838</phoneNumber><address><ns2:address1>520 North Church Street</ns2:address1><ns2:address2>Post Office Box 1411</ns2:address2><ns2:city>Spartanburg</ns2:city><ns2:state>SC</ns2:state><ns2:postalCode>29304</ns2:postalCode><ns2:country>USA</ns2:country></address><emailAddress>http://www.cffcu.org/contactus.html</emailAddress><specialText>Please enter your Carolina Foothills FCU Credit Card Username and Password required for login.</specialText><currencyCode>USD</currencyCode><keys><key><name>Password</name><status>Active</status><displayFlag>true</displayFlag><displayOrder>2</displayOrder><mask>true</mask><description>Password</description></key><key><name>UserName</name><status>Active</status><displayFlag>true</displayFlag><displayOrder>1</displayOrder><mask>false</mask><description>Username</description></key></keys></InstitutionDetail>")
#  IntuitIdsAggcat::Client::Services.get_institution_detail(8860)
#     #=> #<IntuitIdsAggcat::InstitutionDetail:0x007fd22df24930 @id=8860, @name="Carolina Foothills FCU Credit Card" ...
#
#  # simulate a 404 not found for Carolina Foothills FCU Credit Card
#  IntuitIdsAggcat::Client::Services.stub_with("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Status xmlns=\"http://schema.intuit.com/platform/fdatafeed/common/v1\"><errorInfo><errorType>APP_ERROR</errorType><errorCode>api.database.notfound</errorCode><errorMessage>internal api error while processing request</errorMessage><correlationId>gw-9d1c4220-8046-46c2-a5be-2aeddb05f929</correlationId></errorInfo></Status>", 404)
#  IntuitIdsAggcat::Client::Services.get_institution_detail(8860)
#     #=> #<IntuitIdsAggcat::InstitutionDetail:0x007fd233a31670 @id=nil, @name=nil, @url=nil, @phone=nil, @virtual=true, @currency_code=nil, @email_address=nil, @special_text=nil, @address=nil, @keys=[]>
#
#  # simulate getting back unparseable xml
#  IntuitIdsAggcat::Client::Services.stub_with("<xml/>This isn't valid xml<xml/>", 200)
#  IntuitIdsAggcat::Client::Services.get_institution_detail(8860)
#     #=> NoMethodError: undefined method `root' for nil:NilClass



module IntuitIdsAggcat
  module Client    
    class ServicesStub < Struct.new(:body, :code)

      # default code is 200
      def code; self[:code] || '200'; end
      def code=val; self[:code] = val && val.to_s; end

      # calls to http methods return self, which responds to
      # response.body and response.code with the supplied values
      def get *args; self; end
      def post *args; self; end
      def put *args; self; end
      def delete *args; self; end

    end
  end
end

# call Services.stub_with(xml, response_code=200) and pass in an XML string
# it will intercept the outbound oauth request and supply that XML string back
module IntuitIdsAggcat
  module Client    
    class Services

      cattr_accessor :stubbed_values

      class << self

        def stubbed_values # default value is a blank array
          @@stubbed_values ||= []
        end

        def stub_with(xml_string, response_code=200) # push an item to the end of the stack
          self.stubbed_values << ServicesStub.new(xml_string, response_code)
        end

        def clear_stubs
          self.stubbed_values = []
        end

        alias_method :get_access_token_without_stubbing, :get_access_token
        def get_access_token *args
          # delete and return stubbed_value
          if (stubbed_value = stubbed_values.delete_at(0))
            return stubbed_value
          end
          get_access_token_without_stubbing *args
        end

        alias_method :saml_get_tokens_without_stubbing, :saml_get_tokens
        def saml_get_tokens username
          if stubbed_values[0]
            self.last_username = username
            return {}
          end
          get_access_token_without_stubbing(username)
        end
        
      end
    end
  end
end