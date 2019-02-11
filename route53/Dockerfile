FROM python:3-alpine

RUN pip install boto3

ADD update_domains.py /root/update_domains.py

CMD python3 /root/update_domains.py