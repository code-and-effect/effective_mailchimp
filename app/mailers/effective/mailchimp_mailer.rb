module Effective
  class MailchimpMailer < EffectiveMailchimp.parent_mailer_class

    include EffectiveMailer
    include EffectiveEmailTemplatesMailer if EffectiveMailchimp.use_effective_email_templates

    # def mailchimp_submitted(resource, opts = {})
    #   @assigns = assigns_for(resource)
    #   @applicant = resource

    #   subject = subject_for(__method__, "Mailchimp Submitted - #{resource}", resource, opts)
    #   headers = headers_for(resource, opts)

    #   mail(to: resource.user.email, subject: subject, **headers)
    # end

    protected

    def assigns_for(resource)
      if resource.kind_of?(Effective::Mailchimp)
        return mailchimp_assigns(resource)
      end

      raise('unexpected resource')
    end

    def mailchimp_assigns(resource)
      raise('expected an mailchimp') unless resource.class.respond_to?(:effective_mailchimp_resource?)

      values = {
        date: mailchimp.created_at.strftime('%F')
      }.compact

      { mailchimp: values }
    end

  end
end
