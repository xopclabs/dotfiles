# Build sing-box config from base options, converted subscription outbounds, and routing rules.
#
# Inputs (jq --arg / --argjson):
#   $listen_port        - mixed inbound port (e.g. 10808)
#   $bind_interface     - VPS exit interface (e.g. wg-vps), empty to omit
#   $bind_address       - optional source address for VPS exit (e.g. 10.13.13.2)
#   $urltest_url         - health check URL
#   $urltest_interval    - health check interval (e.g. "20s")
#   $custom_domains      - JSON array of domain strings for direct routing
#   $subscription_tags   - JSON array of subscription outbound tags for urltest
#
# Input file: JSON array of converted sing-box outbounds from subscriptions.

($subscription_tags) as $sub_tags
| ($custom_domains) as $domains
| ($sub_tags | length > 0) as $has_subs
| {
    log: { level: "warn" },
    inbounds: [
      {
        type: "mixed",
        tag: "mixed-in",
        listen: "127.0.0.1",
        listen_port: ($listen_port | tonumber)
      }
    ],
    outbounds: (
      [
        { type: "direct", tag: "direct" },
        { type: "block", tag: "block" }
      ]
      + (if $bind_interface != "" then
          [{
            type: "direct",
            tag: "vps-exit",
            bind_interface: $bind_interface
          }
          + (if $bind_address != "" then { inet4_bind_address: $bind_address } else {} end)]
        else [] end)
      + .
      + (if $has_subs then
          [{
            type: "urltest",
            tag: "proxy",
            outbounds: (
              (if $bind_interface != "" then ["vps-exit"] else [] end)
              + $sub_tags
            ),
            url: $urltest_url,
            interval: $urltest_interval,
            tolerance: 50
          }]
        else [] end)
    ),
    route: {
      rule_set: [
        {
          tag: "category-ru",
          type: "local",
          format: "binary",
          path: "/var/lib/sing-box/rule-sets/geosite-category-ru.srs"
        },
        {
          tag: "geoip-ru",
          type: "local",
          format: "binary",
          path: "/var/lib/sing-box/rule-sets/geoip-ru.srs"
        }
      ],
      rules: [
        { inbound: "mixed-in", action: "sniff" }
      ]
      + (
        (if ($domains | length) > 0 then
          [{ domain: $domains, outbound: "direct" }]
        else [] end)
        + [
          { ip_is_private: true, outbound: "direct" },
          { rule_set: "geoip-ru", outbound: "direct" },
          { rule_set: "category-ru", outbound: "direct" }
        ]
      ),
      final: (
        if $has_subs then "proxy"
        elif $bind_interface != "" then "vps-exit"
        else "direct"
        end
      ),
      auto_detect_interface: true
    }
  }
