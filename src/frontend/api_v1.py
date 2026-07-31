# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""JSON REST API for native mobile clients."""

from decimal import Decimal, DecimalException

import requests
from flask import Blueprint, current_app, jsonify, request

api_v1 = Blueprint('api_v1', __name__, url_prefix='/api/v1')


def _cors_headers():
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Access-Control-Allow-Headers': (
            'Authorization,Content-Type,DNT,User-Agent,'
            'X-Requested-With,If-Modified-Since,Cache-Control,Range'
        ),
    }


def _json_response(payload, status=200):
    resp = jsonify(payload)
    for key, value in _cors_headers().items():
        resp.headers[key] = value
    resp.status_code = status
    return resp


def _empty_response(status=204):
    resp = current_app.response_class(status=status)
    for key, value in _cors_headers().items():
        resp.headers[key] = value
    return resp


def _error_response(message, status=400):
    return _json_response({'error': message}, status=status)


def _get_bearer_token():
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return auth[7:].strip()
    return None


def _require_auth(helpers):
    token = _get_bearer_token()
    if not helpers['verify_token'](token):
        return None, _error_response('Unauthorized', 401)
    return token, None


@api_v1.route('/login', methods=['OPTIONS'])
@api_v1.route('/signup', methods=['OPTIONS'])
@api_v1.route('/logout', methods=['OPTIONS'])
@api_v1.route('/home', methods=['OPTIONS'])
@api_v1.route('/deposit', methods=['OPTIONS'])
@api_v1.route('/payment', methods=['OPTIONS'])
def api_options():
    return _empty_response(204)


def register_api_v1(app, helpers):
    """Register mobile JSON API routes with injected helpers from frontend."""

    @api_v1.route('/login', methods=['POST'])
    def api_login():
        body = request.get_json(silent=True) or {}
        username = body.get('username', '').strip()
        password = body.get('password', '')
        if not username or not password:
            return _error_response('Username and password are required', 400)

        result = helpers['login_json'](username, password)
        if result is None:
            return _error_response('Invalid username or password', 401)
        return _json_response(result, 200)

    @api_v1.route('/signup', methods=['POST'])
    def api_signup():
        body = request.get_json(silent=True) or {}
        username = body.get('username', '').strip()
        password = body.get('password', '')
        if not username or not password:
            return _error_response('Username and password are required', 400)

        signup_data = {
            'username': username,
            'password': password,
            'password-repeat': body.get('password_repeat', password),
            'firstname': body.get('firstname', 'Demo'),
            'lastname': body.get('lastname', 'User'),
            'address': body.get('address', '123 Nth Avenue, New York City'),
            'country': body.get('country', 'US'),
            'state': body.get('state', 'NY'),
            'zip': body.get('zip', '10004'),
            'ssn': body.get('ssn', '111-22-3333'),
            'birthday': body.get('birthday', '1990-01-01'),
            'timezone': body.get('timezone', 'America/New_York'),
        }

        if not helpers['signup_json'](signup_data):
            return _error_response('Account creation failed', 400)

        result = helpers['login_json'](username, password)
        if result is None:
            return _error_response('Account created but login failed', 502)
        return _json_response(result, 201)

    @api_v1.route('/logout', methods=['POST'])
    def api_logout():
        token, err = _require_auth(helpers)
        if err:
            return err
        del token
        return _empty_response(204)

    @api_v1.route('/home', methods=['GET'])
    def api_home():
        token, err = _require_auth(helpers)
        if err:
            return err

        try:
            data = helpers['fetch_home_data'](token)
        except requests.exceptions.RequestException:
            current_app.logger.error('Error fetching home data for mobile API')
            return _error_response('Unable to load account data', 502)

        return _json_response(data, 200)

    @api_v1.route('/deposit', methods=['POST'])
    def api_deposit():
        token, err = _require_auth(helpers)
        if err:
            return err

        body = request.get_json(silent=True) or {}
        try:
            amount = int(Decimal(str(body.get('amount', ''))) * 100)
        except (ValueError, DecimalException, TypeError):
            return _error_response('Amount is not a valid number', 400)

        if amount <= 0:
            return _error_response('Amount must be greater than zero', 400)

        txn_uuid = body.get('uuid', '').strip()
        if not txn_uuid:
            return _error_response('Transaction uuid is required', 400)

        try:
            message = helpers['submit_deposit_json'](token, body, amount, txn_uuid)
            return _json_response({'message': message}, 200)
        except UserWarning as warn:
            return _error_response(str(warn), 400)
        except requests.exceptions.RequestException:
            return _error_response('Deposit failed', 502)

    @api_v1.route('/payment', methods=['POST'])
    def api_payment():
        token, err = _require_auth(helpers)
        if err:
            return err

        body = request.get_json(silent=True) or {}
        try:
            amount = int(Decimal(str(body.get('amount', ''))) * 100)
        except (ValueError, DecimalException, TypeError):
            return _error_response('Amount is not a valid number', 400)

        if amount <= 0:
            return _error_response('Amount must be greater than zero', 400)

        txn_uuid = body.get('uuid', '').strip()
        if not txn_uuid:
            return _error_response('Transaction uuid is required', 400)

        try:
            message = helpers['submit_payment_json'](token, body, amount, txn_uuid)
            return _json_response({'message': message}, 200)
        except UserWarning as warn:
            return _error_response(str(warn), 400)
        except requests.exceptions.RequestException:
            return _error_response('Payment failed', 502)

    app.register_blueprint(api_v1)
