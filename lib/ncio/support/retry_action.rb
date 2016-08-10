require 'ncio/support'
module Ncio
  module Support
    ##
    # Provide a method to retry arbitrary code blocks with the ability to rescue
    # certain exceptions and retry rather than failing hard on the exception.
    #
    # Copied from:
    # https://github.com/puppetlabs/puppetlabs-cloud_provisioner/blob/f6cbac3/lib/puppet/cloudpack/utils.rb
    module RetryAction
      class RetryException < RuntimeError
        class NoBlockGiven < RetryException; end
        class NoTimeoutGiven < RetryException; end
        class Timeout < RetryException; end
      end

      def self.timedout?(start, timeout)
        return true if timeout.nil?
        (Time.now - start) >= timeout
      end

      ##
      # Retry an action, catching exceptions and retrying if the exception has
      # been specified.
      #
      # rubocop:disable Metrics/PerceivedComplexity, Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize
      def self.retry_action(params = { retry_exceptions: nil, timeout: nil, log: nil })
        # Retry actions for a specified amount of time. This method will allow
        # the final retry to complete even if that extends beyond the timeout
        # period.
        raise RetryException::NoBlockGiven unless block_given?

        raise RetryException::NoTimeoutGiven if params[:timeout].nil?
        params[:retry_exceptions] ||= []

        # Assumes reset_logging! has been called.  This happens in the Ncio::App
        # initialization.
        log = params[:log] || Ncio::Support.log

        start = Time.now
        failures = 0

        # rubocop:disable Lint/RescueException
        begin
          yield

        rescue Exception => e
          # If we were giving exceptions to catch,
          # catch the exceptions we care about and retry.
          # All others fail hard

          raise RetryException::Timeout if timedout?(start, params[:timeout])

          retry_exceptions = params[:retry_exceptions]

          unless retry_exceptions.empty?
            if retry_exceptions.include?(e.class)
              log.warn("Retrying: #{e.class}: #{e}")
            else
              # If the exceptions is not in the list of retry_exceptions
              # re-raise.
              raise e
            end
          end
          # rubocop:enable Lint/RescueException

          failures += 1
          # Increase the amount of time that we sleep after every
          # failed retry attempt.
          sleep(((2**failures) - 1) * 0.1)

          retry
        end
        # rubocop:enable Metrics/PerceivedComplexity, Metrics/MethodLength
      end
    end
  end
end
