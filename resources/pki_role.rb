require 'vault'

resource_name :vault_pki_intermediate

property :ttl, String, default: '2160h'
property :max_ttl, String, default: '8760h'
property :allow_localhost, Bool, default: true
property :allowed_domains, Array, default: []
property :allow_bare_domains, Bool, default: false
property :allow_subdomains, Bool, default: false
property :allow_glob_domains, Bool, default: false
property :allow_any_name,Bool, default: false
property :enforce_hostnames, Bool, default: true
property :allow_ip_sans, Bool, default: false
property :allowed_uri_sans, String, default: ""
property :server_flag, Bool, default: true
property :client_flag, Bool,default: true
property :code_signing_flag, Bool, default: false
property :email_protection_flag, Bool, default: false
property :key_type, %w(rsa ec), default: 'rsa'
property :key_bits, Integer, default: 2048
property :key_usage, Array, default: %w(DigitalSignature KeyAgreement KeyEncipherment)
property :ext_key_usage, Array, default: []
property :use_csr_common_name, Bool, default: true
property :use_csr_sans, Bool, default: true
property :ou, Array, default: []
property :organization, Array, default: []
property :country, Array, default: []
property :locality, Array, default: []
property :province, Array, default: []
property :street_address, Array, default: []
property :postal_code, Array, default: []
property :generate_lease, Bool, default: false
property :no_store, Bool, default: false
property :require_cn, Bool, default: true
property :policy_identifiers, Array,  default: []
property :basic_constraints_valid_for_non_ca, Bool, default: false
property :not_before_duration, String, default: '30s'

property :vault_backend, String, default: 'pki', desired_state: false
property :vault_auth_method, String, default: 'token', desired_state: false, callbacks: {
    "should be one of Vault::Authenticate methods: #{Vault::Authenticate.instance_methods(false)}" => lambda do |m|
      Vault.auth.respond_to?(m)
    end,
}
property :vault_auth_credentials, Array, desired_state: false, default: [], sensitive: true
#<> @property vault_client_options Define the option to pass to vault client, could be empty to use environment variables.
property :vault_client_options, Hash, desired_state: false, default: {}, callbacks: {
    "options should only include valid keys: #{Vault::Configurable.keys}" => lambda do |v|
      (v.keys.map { |k| k.is_a?(String) ? k.to_sym : k } - Vault::Configurable.keys).empty?
    end,
    'address should be a valid url' => lambda do |v|
      v.empty? || URI.parse(v['address'])
    end,
}
#<> @property vault_role where to mount this pki backend in vault.
property :vault_role, String, name_property: true

load_current_value do |desired|
  vault_auth
  begin
    role = @vault.with_retries do |attempts, error|
      Chef::Log.info "Received exception #{error.class} from Vault - attempt #{attempts}" unless attempts == 0
      @vault.logical.read(
          "/#{vault_backend}/roles/#{vault_role}",

      )
    end
    role.data.each do |k,v|
      send(k,v)
    end
  rescue Vault::HTTPError => e
    current_value_does_not_exist!
  end
end

action :create do
  converge_if_changed do
    begin
      @vault.with_retries do |attempts, error|
        Chef::Log.info "Received exception #{error.class} from Vault - attempt #{attempts}" unless attempts == 0
        @vault.logical.write(
            "/#{vault_backend}/roles/#{vault_role}",
            ttl: new_resource.ttl,
            max_ttl: new_resource.max_ttl,
            allow_localhost: new_resource.allow_localhost,
            allowed_domains: new_resource.allowed_domains,
            allow_bare_domains: new_resource.allow_bare_domains,
            allow_subdomains: new_resource.allow_subdomains,
            allow_glob_domains: new_resource.allow_glob_domains,
            allow_any_name: new_resource.allow_any_name,
            enforce_hostnames: new_resource.enforce_hostnames,
            allow_ip_sans: new_resource.allow_ip_sans,
            allowed_uri_sans: new_resource.allowed_uri_sans,
            server_flag: new_resource.server_flag,
            client_flag: new_resource.client_flag,
            code_signing_flag: new_resource.code_signing_flag,
            email_protection_flag: new_resource.email_protection_flag,
            key_type: new_resource.key_type,
            key_bits: new_resource.key_bits,
            key_usage: new_resource.key_usage,
            ext_key_usage: new_resource.ext_key_usage,
            use_csr_common_name: new_resource.use_csr_common_name,
            use_csr_sans: new_resource.use_csr_sans,
            ou: new_resource.ou,
            organization: new_resource.organization,
            country: new_resource.country,
            locality: new_resource.locality,
            province: new_resource.province,
            street_address: new_resource.street_address,
            postal_code: new_resource.postal_code,
            generate_lease: new_resource.generate_lease,
            no_store: new_resource.no_store,
            require_cn: new_resource.require_cn,
            policy_identifiers: new_resource.policy_identifiers,
            basic_constraints_valid_for_non_ca: new_resource.basic_constraints_valid_for_non_ca,
            not_before_duration: new_resource.not_before_duration
        )
      end
    rescue Vault::HTTPError => e
      message = "Failed to create pki role - #{new_resource.vault_role}.\n#{e.message}"
      Chef::Log.fatal message
    end
  end
end

action :delete do
  converge_by do
    begin
      @vault.with_retries do |attempts, error|
        Chef::Log.info "Received exception #{error.class} from Vault - attempt #{attempts}" unless attempts == 0
        @vault.logical.write(
            "/#{vault_backend}/roles/#{vault_role}"
        )
      end
    rescue Vault::HTTPError => e
      message = "Failed to delete pki role - #{new_resource.vault_role}.\n#{e.message}"
      Chef::Log.fatal message
    end
  end
end

action_class do
  def vault_auth
    @vault = Vault::Client.new(new_resource.vault_client_options)
    @vault.auth.send new_resource.vault_auth_method, *new_resource.vault_auth_credentials
  end
end