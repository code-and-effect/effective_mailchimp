module Admin
  class EffectiveMailchimpListsDatatable < Effective::Datatable
    datatable do
      order :updated_at

      col :updated_at, visible: false
      col :created_at, visible: false
      col :id, visible: false

      col :mailchimp_id, visible: false
      col :web_id, visible: false

      col :name
      col :can_subscribe, label: 'Users can opt-in'

      col :url, label: 'Campaign' do |ml|
        link_to('View Campaign', ml.url, target: '_blank')
      end

      col :members_url, label: 'Members' do |ml|
        link_to('View Members', ml.members_url, target: '_blank')
      end

      actions_col
    end

    collection do
      Effective::MailchimpList.deep.all
    end
  end
end
