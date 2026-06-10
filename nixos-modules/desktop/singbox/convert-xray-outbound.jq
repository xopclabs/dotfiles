# Convert a single Xray outbound object to a sing-box outbound.
# Usage: jq -f convert-xray-outbound.jq --arg tag my-tag xray-outbound.json

def stream_network:
  .streamSettings.network // "tcp";

def tls_fields:
  if (.streamSettings.security // "") == "reality" then
    {
      enabled: true,
      server_name: (.streamSettings.realitySettings.serverName // ""),
      reality: {
        enabled: true,
        public_key: .streamSettings.realitySettings.publicKey,
        short_id: (.streamSettings.realitySettings.shortId // "")
      }
    }
    + if (.streamSettings.realitySettings.fingerprint // "") != "" then
        { utls: { enabled: true, fingerprint: .streamSettings.realitySettings.fingerprint } }
      else {} end
  elif (.streamSettings.security // "") == "tls" then
    {
      enabled: true,
      server_name: (.streamSettings.tlsSettings.serverName // "")
    }
    + if (.streamSettings.tlsSettings.fingerprint // "") != "" then
        { utls: { enabled: true, fingerprint: .streamSettings.tlsSettings.fingerprint } }
      else {} end
  else {} end;

def transport_fields:
  if stream_network == "ws" then
    {
      type: "ws",
      path: (.streamSettings.wsSettings.path // "/"),
      headers: (.streamSettings.wsSettings.headers // {})
    }
  elif stream_network == "grpc" then
    {
      type: "grpc",
      service_name: (.streamSettings.grpcSettings.serviceName // "")
    }
  elif stream_network == "h2" then
    {
      type: "http",
      host: (.streamSettings.httpSettings.host // []),
      path: (.streamSettings.httpSettings.path // "/")
    }
  else {} end;

def vless_server:
  if .settings.vnext then
    .settings.vnext[0]
  else
    {
      address: .settings.address,
      port: .settings.port,
      users: [{
        id: .settings.id,
        flow: (.settings.flow // ""),
        encryption: (.settings.encryption // "none")
      }]
    }
  end;

def vless_user:
  vless_server.users[0];

def to_vless:
  {
    type: "vless",
    tag: $tag,
    server: vless_server.address,
    server_port: vless_server.port,
    uuid: vless_user.id
  }
  + if (vless_user.flow // "") != "" then { flow: vless_user.flow } else {} end
  + if (tls_fields | length) > 0 then { tls: tls_fields } else {} end
  + if (transport_fields | length) > 0 then { transport: transport_fields } else {} end;

def vmess_server:
  if .settings.vnext then .settings.vnext[0]
  else {
    address: .settings.address,
    port: .settings.port,
    users: [{
      id: .settings.id,
      alterId: (.settings.alterId // 0),
      security: (.settings.security // "auto")
    }]
  }
  end;

def to_vmess:
  {
    type: "vmess",
    tag: $tag,
    server: vmess_server.address,
    server_port: vmess_server.port,
    uuid: vmess_server.users[0].id,
    security: (vmess_server.users[0].security // "auto"),
    alter_id: (vmess_server.users[0].alterId // 0)
  }
  + if (tls_fields | length) > 0 then { tls: tls_fields } else {} end
  + if (transport_fields | length) > 0 then { transport: transport_fields } else {} end;

def to_shadowsocks:
  {
    type: "shadowsocks",
    tag: $tag,
    server: .settings.servers[0].address,
    server_port: .settings.servers[0].port,
    method: .settings.servers[0].method,
    password: .settings.servers[0].password
  }
  + if (tls_fields | length) > 0 then { tls: tls_fields } else {} end
  + if (transport_fields | length) > 0 then { transport: transport_fields } else {} end;

def to_trojan:
  {
    type: "trojan",
    tag: $tag,
    server: .settings.servers[0].address,
    server_port: .settings.servers[0].port,
    password: .settings.servers[0].password
  }
  + if (tls_fields | length) > 0 then { tls: tls_fields } else {} end
  + if (transport_fields | length) > 0 then { transport: transport_fields } else {} end;

if .protocol == "vless" then to_vless
elif .protocol == "vmess" then to_vmess
elif .protocol == "shadowsocks" then to_shadowsocks
elif .protocol == "trojan" then to_trojan
else error("unsupported xray protocol: \(.protocol)")
end
