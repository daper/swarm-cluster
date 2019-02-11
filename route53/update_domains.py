import boto3, json, re, time

IPv4='<IPV4>'
IPv6='<IPV6>'

def main():
  client = boto3.client('route53')
  try:
    calls = json.load(open('./dns_calls.json'))['calls']
  except Exception as e:
    print('Cannot load calls settings.\n{}'.format(e))
    return

  for call_id, call in enumerate(calls):
    calls[call_id]['ChangeBatch']['Comment'] = 'Automatically updated on {}'.format(time.strftime('%Y-%m-%d %H:%M:%S'))
    for change_id, change in enumerate(call['ChangeBatch']['Changes']):
      if change['ResourceRecordSet']['Type'] == 'A':
        calls[call_id]['ChangeBatch']['Changes'][change_id]['ResourceRecordSet']['ResourceRecords'][0]['Value'] = IPv4
      elif change['ResourceRecordSet']['Type'] == 'AAAA':
        calls[call_id]['ChangeBatch']['Changes'][change_id]['ResourceRecordSet']['ResourceRecords'][0]['Value'] = IPv6

  for call in calls:
    print('Updating domain {}...'.format(call['ChangeBatch']['Changes'][0]['ResourceRecordSet']['Name']))
    print('HostedZoneId={}, ChangeBatch={}'.format(call['HostedZoneId'], call['ChangeBatch']))
    change_id = client.change_resource_record_sets(HostedZoneId=call['HostedZoneId'], ChangeBatch=call['ChangeBatch'])
    change_id = change_id['ChangeInfo']['Id']
    while True:
      print('Waiting for change to take effect')
      change_resp = client.get_change(Id=change_id)
      if change_resp['ChangeInfo']['Status'] == 'INSYNC':
        break
      else:
        time.sleep(1)
    print('Updated successfully!')

if __name__ == '__main__':
  main()