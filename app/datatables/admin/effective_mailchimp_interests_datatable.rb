module Admin
  class EffectiveMailchimpInterestsDatatable < Effective::Datatable
    filters do
      scope :all
      scope :subscribable
    end

    datatable do
      length :all
      order :display_order

      col :updated_at, visible: false
      col :created_at, visible: false
      col :id, visible: false

      col :mailchimp_list
      col :mailchimp_category

      col :list_id, visible: false
      col :category_id, visible: false
      col :mailchimp_id, visible: false

      col :name
      col :can_subscribe
      col :force_subscribe

      col :list_name, visible: false
      col :category_name, visible: false
      col :display_order, visible: false

      col :subscriber_count

      actions_col
    end

    collection do
      scope = Effective::MailchimpInterest.deep

      if attributes[:mailchimp_category_id].present?
        scope = scope.sorted
      end

      scope

    end
  end
end
