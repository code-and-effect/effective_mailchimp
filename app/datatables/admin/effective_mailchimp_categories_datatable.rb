module Admin
  class EffectiveMailchimpCategoriesDatatable < Effective::Datatable

    datatable do
      length :all

      order :name

      col :updated_at, visible: false
      col :created_at, visible: false
      col :id, visible: false

      col :mailchimp_list

      col :list_id, visible: false
      col :mailchimp_id, visible: false

      col :name
      col :list_name, visible: false

      col :display_type

      col :mailchimp_interests

      actions_col
    end

    collection do
      Effective::MailchimpCategory.deep.all
    end
  end
end
