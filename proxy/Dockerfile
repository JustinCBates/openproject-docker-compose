FROM caddy:2

COPY ./Caddyfile.template /etc/caddy/Caddyfile.template
COPY ./entrypoint.sh /usr/local/bin/proxy-entrypoint.sh
RUN chmod +x /usr/local/bin/proxy-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/proxy-entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
