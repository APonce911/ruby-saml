module OneLogin
  module RubySaml
    class Logoutrequest < SamlMessage

      attr_reader :uuid # Can be obtained if neccessary

      def initialize
        @uuid = "_" + UUID.new.generate
      end

      def create(settings, params={})
        request_doc = create_unauth_xml_doc(settings, params)
        request = ""
        request_doc.write(request)

        deflated_request  = Zlib::Deflate.deflate(request, 9)[2..-5]
        base64_request    = Base64.encode64(deflated_request)
        encoded_request   = CGI.escape(base64_request)

        params_prefix     = (settings.idp_slo_target_url =~ /\?/) ? '&' : '?'
        request_params    = "#{params_prefix}SAMLRequest=#{encoded_request}"

        params.each_pair do |key, value|
          request_params << "&#{key}=#{CGI.escape(value.to_s)}"
        end

        @logout_url = settings.idp_slo_target_url + request_params
      end

      def create_unauth_xml_doc(settings, params)

        time = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")

        request_doc = XMLSecurity::RequestDocument.new
        root = request_doc.add_element "samlp:LogoutRequest", { "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol" }
        root.attributes['ID'] = @uuid
        root.attributes['IssueInstant'] = time
        root.attributes['Version'] = "2.0"

        if settings.issuer
          issuer = root.add_element "saml:Issuer", { "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion" }
          issuer.text = settings.issuer
        end

        if settings.name_identifier_value
          name_id = root.add_element "saml:NameID", { "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion" }
          name_id.attributes['NameQualifier'] = settings.sp_name_qualifier if settings.sp_name_qualifier
          name_id.attributes['Format'] = settings.name_identifier_format if settings.name_identifier_format
          name_id.text = settings.name_identifier_value
        else
          # If no NameID is present in the settings we generate one
          name_id.text = "_" + UUID.new.generate
          name_id.attributes['Format'] = 'urn:oasis:names:tc:SAML:2.0:nameid-format:transient'
        end

        if settings.sessionindex
          sessionindex = root.add_element "samlp:SessionIndex", { "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol" }
          sessionindex.text = settings.sessionindex
        end

        if settings.authn_context != nil
          requested_context = root.add_element "samlp:RequestedAuthnContext", {
              "xmlns:samlp" => "urn:oasis:names:tc:SAML:2.0:protocol",
              "Comparison" => "exact",
          }
          class_ref = requested_context.add_element "saml:AuthnContextClassRef", {
              "xmlns:saml" => "urn:oasis:names:tc:SAML:2.0:assertion",
          }
          class_ref.text = settings.authn_context
        end

        if settings.sign_request && settings.private_key && settings.certificate
          request_doc.sign_document(settings.private_key, settings.certificate, settings.signature_method, settings.digest_method)
        end

        request_doc
      end
    end
  end
end
