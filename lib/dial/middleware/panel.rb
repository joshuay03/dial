# frozen_string_literal: true

require "uri"

module Dial
  class Panel
    class << self
      def html env, headers, profile_out_filename, query_logs, ruby_vm_stat, gc_stat, gc_stat_heap, server_timing
        <<~HTML
          <style>#{style}</style>

          <div id="dial">
            <div id="dial-preview">
              <span>
                #{formatted_rails_route_info env} |
                #{formatted_request_timing env} |
                #{formatted_profile_output env, profile_out_filename}
              </span>
              <span>#{formatted_rails_version}</span>
              <span>#{formatted_rack_version}</span>
              <span>#{formatted_ruby_version}</span>
            </div>

            <hr>

            <div id="dial-details">
              <details>
                <summary>N+1s</summary>
                <div class="section query-logs">
                  #{formatted_query_logs query_logs}
                </div>
              </details>

              <hr>

              <details>
                <summary>Server timing</summary>
                <div class="section">
                  #{formatted_server_timing server_timing}
                </div>
              </details>

              <hr>

              <details>
                <summary>RubyVM stat</summary>
                <div class="section">
                  #{formatted_ruby_vm_stat ruby_vm_stat}
                </div>
              </details>

              <hr>

              <details>
                <summary>GC stat</summary>
                <div class="section">
                  #{formatted_gc_stat gc_stat}
                </div>
              </details>

              <hr>

              <details>
                <summary>GC stat heap</summary>
                <div class="section">
                  #{formatted_gc_stat_heap gc_stat_heap}
                </div>
              </details>
            </div>
          </div>

          <script nonce="#{configured_nonce env, headers}">
            #{script}
          </script>
        HTML
      end

      private

      def style
        <<~CSS
          #dial {
            max-height: 50%;
            max-width: 50%;
            z-index: 9999;
            position: fixed;
            bottom: 0;
            right: 0;
            background-color: white;
            border-top-left-radius: 1rem;
            box-shadow: -0.2rem -0.2rem 0.4rem rgba(0, 0, 0, 0.5);
            display: flex;
            flex-direction: column;
            padding: 0.5rem;
            font-size: 0.85rem;

            #dial-preview {
              display: flex;
              flex-direction: column;
              cursor: pointer;
            }

            #dial-details {
              display: none;
              overflow-y: auto;
            }

            .section {
              display: flex;
              flex-direction: column;
              margin: 0.25rem 0 0 0;
            }

            .query-logs {
              padding-left: 0.75rem;

              details {
                margin-top: 0;
                margin-bottom: 0.25rem;
              }
            }

            span {
              text-align: left;
              color: black;
            }

            a {
              color: blue;
            }

            hr {
              width: -moz-available;
              margin: 0.65rem 0 0 0;
              border-color: black;
            }

            details {
              margin: 0.5rem 0 0 0;
              text-align: left;
            }

            summary {
              margin: 0.25rem 0 0 0;
              cursor: pointer;
              color: black;
            }
          }
        CSS
      end

      def script
        <<~JS
          var dialPreview = document.getElementById("dial-preview");
          var dialDetails = document.getElementById("dial-details");

          dialPreview.addEventListener("click", () => {
            var collapsed = ["", "none"].includes(dialDetails.style.display);
            dialDetails.style.display = collapsed ? "block" : "none";
          });

          document.addEventListener("click", (event) => {
            if (!dialPreview.contains(event.target) && !dialDetails.contains(event.target)) {
              dialDetails.style.display = "none";

              var detailsElements = dialDetails.querySelectorAll("details");
              detailsElements.forEach(detail => {
                detail.removeAttribute("open");
              });
            }
          });
        JS
      end

      def formatted_rails_route_info env
        begin
          ::Rails.application.routes.recognize_path env[::Rack::PATH_INFO], method: env[::Rack::REQUEST_METHOD]
        rescue ::ActionController::RoutingError
          {}
        end.then do |info|
          "<b>Controller:</b> #{info[:controller] || "N/A"} | <b>Action:</b> #{info[:action] || "N/A"}"
        end
      end

      def formatted_request_timing env
        "<b>Request timing:</b> #{env[REQUEST_TIMING]}ms"
      end

      def formatted_profile_output env, profile_out_filename
        url_base = ::Rails.application.routes.url_helpers.dial_url host: env[::Rack::HTTP_HOST]
        prefix = "/" unless url_base.end_with? "/"
        uuid = profile_out_filename.delete_suffix ".json.gz"
        profile_out_url = URI.encode_www_form_component url_base + "#{prefix}dial/profile?uuid=#{uuid}"

        "<a href='https://vernier.prof/from-url/#{profile_out_url}' target='_blank'>View profile</a>"
      end

      def formatted_rails_version
        "<b>Rails version:</b> #{::Rails::VERSION::STRING}"
      end

      def formatted_rack_version
        "<b>Rack version:</b> #{::Rack.release}"
      end

      def formatted_ruby_version
        "<b>Ruby version:</b> #{::RUBY_DESCRIPTION}"
      end

      def formatted_server_timing server_timing
        if server_timing.any?
          server_timing
            .sort_by { |_, timing| -timing }
            .map { |event, timing| "<span><b>#{event}:</b> #{timing}</span>" }.join
        else
          "<span>N/A</span>"
        end
      end

      def formatted_query_logs query_logs
        if query_logs.any?
          query_logs.map do |(queries, stack_lines)|
            <<~HTML
              <details>
                <summary>#{queries.shift}</summary>
                <div class="section query-logs">
                  #{queries.map { |query| "<span>#{query}</span>" }.join}
                  #{stack_lines.map { |stack_line| "<span>#{stack_line}</span>" }.join}
                </div>
              </details>
            HTML
          end.join
        else
          "<span>N/A</span>"
        end
      end

      def formatted_ruby_vm_stat ruby_vm_stat
        ruby_vm_stat.map { |key, value| "<span><b>#{key}:</b> #{value}</span>" }.join
      end

      def formatted_gc_stat gc_stat
        gc_stat.map { |key, value| "<span><b>#{key}:</b> #{value}</span>" }.join
      end

      def formatted_gc_stat_heap gc_stat_heap
        gc_stat_heap.map do |slot, stats|
          <<~HTML
            <div class="section">
              <span><u>Heap slot #{slot}</u></span>
              <div class="section">
                #{gc_stat_heap[slot].map { |key, value| "<span><b>#{key}:</b> #{value}</span>" }.join}
              </div>
            </div>
          HTML
        end.join
      end

      def configured_nonce env, headers
        config_nonce = Dial._configuration.content_security_policy_nonce
        if config_nonce.instance_of? Proc
          config_nonce.call env, headers
        else
          config_nonce
        end
      end
    end
  end
end
