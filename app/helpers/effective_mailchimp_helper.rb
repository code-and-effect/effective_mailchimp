module EffectiveMailchimpHelper

  def mailchimp_user_fields(form)
    raise('expected a form') unless form.respond_to?(:object)

    resource = form.object
    raise('expected an effective_mailchimp_user resource') unless resource.class.respond_to?(:effective_mailchimp_user?)

    render('effective/mailchimp_user/fields', form: form, f: form, resource: resource, mailchimp_user: resource)
  end

end
