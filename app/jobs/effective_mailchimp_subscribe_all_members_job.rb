class EffectiveMailchimpSubscribeAllMembersJob < ApplicationJob

  def perform(mailchimp_list)
    raise('expected an Effective::MailchimpList') unless mailchimp_list.kind_of?(Effective::MailchimpList)
    mailchimp_list.subscribe_all_members!(now: true)
  end

end
