#!/bin/bash

set -e

# settings.py reads the following files. We use Key Vault import to store the certificate securely and use WEBSITE_LOAD_CERTIFICATES environment variable to tell Azure Web App to load the certificate from Key Vault and mount it to /var/ssl/private/(thumbprint).p12. We then split the certificate back into a .key and .crt pair here.
mkdir -p /app/certs
openssl pkcs12 -in /var/ssl/private/$TURKU_ADFS_CERTIFICATE_THUMBPRINT.p12 -nocerts -out /app/certs/turku_adfs.key -nodes -passin pass:
openssl pkcs12 -in /var/ssl/private/$TURKU_ADFS_CERTIFICATE_THUMBPRINT.p12 -clcerts -nokeys -out /app/certs/turku_adfs.crt -passin pass:
chown appuser /app/certs/*

if [[ "$ENABLE_SSH" = "true" ]]; then
      echo Enabling SSH
      service ssh start
      eval $(printenv | sed -n "/^PWD=/!s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)
      echo Enabled SSH
fi

if [ -n "$DATABASE_HOST" ]; then
  until nc -z -v -w30 "$DATABASE_HOST" 5432
  do
    echo "Waiting for postgres database connection..."
    sleep 1
  done
  echo "Database is up!"
fi

# Apply database migrations
if [[ "$APPLY_MIGRATIONS" = "1" ]]; then
    echo "Applying database migrations..."
    ./manage.py migrate --noinput
fi

if [[ "$SETUP_DEV_OIDC" = "1" ]]; then
    echo "Setting up a OIDC test environments"
    ./manage.py add_oidc_client \
      --confidential \
      --name Helsinkiprofile \
      --response_types "id_token token" \
      --redirect_uris https://oidcdebugger.com/debug \
      --client_id https://api.hel.fi/auth/helsinkiprofile \
      --site_type dev \
      --login_methods github

    ./manage.py add_oidc_client \
      --confidential \
      --name Project \
      --response_types code \
      --redirect_uris \
        http://localhost:8001/complete/tunnistamo/ \
        http://omahelsinki:8001/complete/tunnistamo/ \
        https://oidcdebugger.com/debug \
        http://tunnistamo-backend:8000/accounts/github/login/callback/ \
      --client_id http://tunnistamo-backend:8000/project \
      --site_type dev \
      --login_methods github \
      --scopes "https://api.hel.fi/auth/helsinkiprofile login_entries consents email profile"

    ./manage.py add_oidc_api \
      --name helsinkiprofile \
      --domain https://api.hel.fi/auth \
      --scopes profile email \
      --client_id https://api.hel.fi/auth/helsinkiprofile

    ./manage.py add_oidc_api_scope \
      --name Helsinkiprofile \
      --api_name helsinkiprofile \
      --description "Profile backend" \
      --client_ids https://api.hel.fi/auth/helsinkiprofile

    echo "The following test OIDC environments are available:

  # PROFILE CLIENT & API
  Client id      : https://api.hel.fi/auth/helsinkiprofile
  Response types : id_token token
  Login methods  : GitHub
  Redirect URLs  : https://oidcdebugger.com/debug
  API Scope      : profile, email

  # PROJECT CLIENT
  Client id      : http://tunnistamo-backend:8000/project (please add 'tunnistamo-backend' to your hosts file)
  Response types : code
  Login methods  : GitHub, Google, Yle Tunnus
  Redirect URLs  : http://localhost:8000/complete/tunnistamo/ & https://oidcdebugger.com/debug
  Scopes: https://api.hel.fi/auth/helsinkiprofile login_entries consents email profile

  To change the settings, please visit the admin panel and change
  the Client, API and API Scope accordingly.
"
fi


if [[ "$GENERATE_OPENID_KEY" = "1" ]]; then
    # (Re-)Generate OpenID RSA key if needed
    ./manage.py manage_openid_keys
fi

if [[ "$CREATE_SUPERUSER" = "1" ]]; then
    ./manage.py add_admin_user -u admin -p admin -e admin@example.com
    echo "Admin user created with credentials admin:admin (email: admin@example.com)"
fi

# Start server
if [[ ! -z "$@" ]]; then
    "$@"
elif [[ "$DEV_SERVER" = "1" ]]; then
    python ./manage.py runserver 0.0.0.0:8000
else
    uwsgi --ini .prod/uwsgi.ini
fi
