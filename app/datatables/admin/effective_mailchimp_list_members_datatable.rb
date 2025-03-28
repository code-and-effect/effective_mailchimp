module Admin
  class EffectiveMailchimpListMembersDatatable < Effective::Datatable
    filters do
      scope :all
      scope :subscribed
    end

    datatable do
      order :updated_at

      col :updated_at, visible: false
      col :created_at, visible: false
      col :id, visible: false

      col :mailchimp_list
      col :user

      col :mailchimp_id, visible: false
      col :web_id, visible: false

      col :email_address
      col :full_name
      col :subscribed
      col :cannot_be_subscribed

      col :interests, visible: false
      col :mailchimp_interests, search: { collection: Effective::MailchimpInterest.order(:name), fuzzy: true }

      col :last_synced_at

      actions_col do |member|
        dropdown_link_to('Edit', "/admin/users/#{member.user.to_param}/edit#tab-mailchimp", 'data-turbolinks': false)
      end
    end

    collection do
      Effective::MailchimpListMember.deep.all
    end
  end
end
