#!/usr/bin/env python3
"""Exercise weather HTTP and native location handling without live requests."""
import importlib.machinery
import json
import os
from pathlib import Path
import tempfile
import unittest.mock as mock

helper = importlib.machinery.SourceFileLoader('island_weather', str(Path(__file__).resolve().parents[1]/'plugin/bin/weather-data')).load_module()
assert helper.point({'latitude':91,'longitude':0}) is None
assert helper.point({'latitude':'nan','longitude':0}) is None
with tempfile.TemporaryDirectory(prefix='island-weather-') as temporary:
    home = Path(temporary)
    location = home/'.local/state/omarchy/settings/weather.json'
    location.parent.mkdir(parents=True)
    location.write_text(json.dumps({'name':'Chosen city','latitude':55.7,'longitude':37.6}))
    calls=[]
    def fetch(url):
        calls.append(url)
        if 'geocoding-api' in url:
            return {'results':[{'name':'Paris','latitude':48.8,'longitude':2.3,'country':'France'}]}
        if 'geo.omarchy' in url:
            return {'name':'Detected city','latitude':30,'longitude':40}
        return {'current':{'temperature_2m':5},'daily':{}}
    with mock.patch.dict(os.environ,HOME=str(home)), mock.patch.object(helper,'fetch',fetch):
        report=helper.forecast()
        assert report['location']['name']=='Chosen city'
        assert len(calls)==1 and 'latitude=55.7' in calls[0]
        assert helper.urllib.parse.parse_qs(helper.urllib.parse.urlsplit(calls[0]).query)['forecast_days']==['8']
        location.write_text(json.dumps({'name':'Paris'}));calls.clear()
        assert helper.forecast()['location']['name']=='Paris'
        assert 'geocoding-api' in calls[0] and len(calls)==2
        location.unlink();calls.clear()
        assert helper.forecast()['location']['name']=='Detected city'
        assert 'geo.omarchy' in calls[0] and len(calls)==2
        calls.clear();helper.search('Paris & x=bad','ru')
        assert 'name=Paris+%26+x%3Dbad' in calls[0] and 'language=ru' in calls[0]
    response=mock.MagicMock()
    response.__enter__.return_value=response
    response.url='https://api.open-meteo.com/v1/forecast'
    response.read.return_value=b'x'*(helper.MAX_BYTES+1)
    with mock.patch.object(helper.urllib.request,'urlopen',return_value=response):
        try:
            helper.fetch('https://api.open-meteo.com/v1/forecast')
            raise AssertionError('Oversized response was accepted')
        except ValueError:
            pass
print('PASS: native weather location, auto detection, city lookup and bounded HTTP responses.')
