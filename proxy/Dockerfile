FROM caddy:2

# Install curl for runtime diagnostics. caddy:2 is Alpine-based.
RUN apk add --no-cache curl

# Ship the template; the renderer will render and place /etc/caddy/Caddyfile at deploy time.
COPY ./Caddyfile.template /etc/caddy/Caddyfile.template

# Rendered at deploy time by scripts/deploy/render_caddy.sh using gomplate.
ENTRYPOINT ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
