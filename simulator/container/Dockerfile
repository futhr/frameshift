FROM elixir:1.20.4-otp-29-slim@sha256:3898ffe18d695e770239e4b342dc6b83136f52da0a37df2298083c03068cfd4e

WORKDIR /receiver
COPY receiver.exs /receiver/receiver.exs

ENTRYPOINT ["elixir", "/receiver/receiver.exs"]
