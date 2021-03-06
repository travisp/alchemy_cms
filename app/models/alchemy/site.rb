# == Schema Information
#
# Table name: alchemy_sites
#
#  id                       :integer          not null, primary key
#  host                     :string(255)
#  name                     :string(255)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  public                   :boolean          default(FALSE)
#  aliases                  :text
#  redirect_to_primary_host :boolean
#

module Alchemy
  class Site < ActiveRecord::Base
    # validations
    validates_presence_of :host
    validates_uniqueness_of :host

    # associations
    has_many :languages

    scope :published, -> { where(public: true) }

    # Callbacks
    before_create :create_default_language, unless: -> { languages.any? }

    # concerns
    include Alchemy::Site::Layout

    # Returns true if this site is the current site
    def current?
      self.class.current == self
    end

    # Returns the path to site's view partial.
    #
    # Site view partials live in +app/views/alchemy/site_layouts+
    #
    # Please use <tt>rails g alchemy:site_layouts</tt> to generate partials for all your sites.
    #
    def to_partial_path
      "alchemy/site_layouts/#{partial_name}"
    end

    class << self
      def current=(v)
        RequestStore.store[:alchemy_current_site] = v
      end

      def current
        RequestStore.store[:alchemy_current_site] || default
      end

      def default
        Site.first
      end

      def find_for_host(host)
        # These are split up into two separate queries in order to run the
        # fastest query first (selecting the domain by its primary host name).
        #
        find_by(host: host) || find_in_aliases(host) || default
      end

      def find_in_aliases(host)
        return nil if host.blank?

        all.find do |site|
          site.aliases.split.include?(host) if site.aliases.present?
        end
      end
    end

    private

    # If no languages are present, create a default language based
    # on the host app's Alchemy configuration.
    def create_default_language
      default_language = Alchemy::Config.get(:default_language)
      languages.build(
        name:           default_language['name'],
        language_code:  default_language['code'],
        locale:         default_language['code'],
        frontpage_name: default_language['frontpage_name'],
        page_layout:    default_language['page_layout'],
        public:         true,
        default:        true
      )
    end
  end
end
