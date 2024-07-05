module EffectiveMailchimpHelper

  def mailchimp_list_member_interests_collection(mailchimp_interests)
    interests = mailchimp_interests.select { |interest| interest.can_subscribe? || interest.force_subscribe? }

    interests.map do |interest| 
      label = (interest.force_subscribe? ? (interest.to_s + ' ' + content_tag(:small, 'required', class: 'text-hint')) : interest.to_s).html_safe
      [label, interest.mailchimp_id, disabled: (interest.force_subscribe || !interest.can_subscribe?)]
    end
  end

end
