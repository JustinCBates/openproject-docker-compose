FROM caddy:2

COPY ./Caddyfile.template /etc/caddy/Caddyfile.template

# Rendered at deploy time by scripts/deploy/render_caddy.sh using gomplate.
ENTRYPOINT ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
