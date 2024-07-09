module Admin
  class EffectiveMailchimpListsDatatable < Effective::Datatable
    filters do
      scope :all
      scope :subscribable
    end

    datatable do
      length :all
      order :name

      col :updated_at, visible: false
      col :created_at, visible: false
      col :id, visible: false

      col :mailchimp_id, visible: false
      col :web_id, visible: false

      col :name
      col :can_subscribe
      col :force_subscribe

      col :url, label: 'Mailchimp' do |ml|
        [
          link_to('View Members', ml.members_url, target: '_blank'),
          link_to('View Merge Fields', ml.merge_fields_url, target: '_blank')
        ].join('<br>').html_safe
      end

      col :merge_fields, visible: false do |ml|
        ml.merge_fields.join(', ')
      end

      col :member_count do |list|
        list.member_count.to_i
      end

      actions_col
    end

    collection do
      Effective::MailchimpList.deep.all
    end
  end
end
