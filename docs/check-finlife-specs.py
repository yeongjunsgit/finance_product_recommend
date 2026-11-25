"""Read public specification tables only; never calls credentialed data APIs."""
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
import html as html_module
import hashlib
import json
from pathlib import Path
import re
import sys
import requests


class TableReader(HTMLParser):
    def __init__(self):
        super().__init__()
        self.row = None
        self.cell = None
        self.rows = []
        self.text = []

    def handle_starttag(self, tag, attrs):
        if tag == 'tr': self.row = []
        if tag in ('td', 'th'): self.cell = []

    def handle_data(self, text):
        self.text.append(text)
        if self.cell is not None: self.cell.append(text)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            if self.row is not None: self.row.append(re.sub(r'\s+', ' ', ''.join(self.cell)).strip())
            self.cell = None
        if tag == 'tr' and self.row is not None:
            self.rows.append(self.row)
            self.row = None


pages = {
    '정기예금': 'https://finlife.fss.or.kr/finlife/api/fdrmDpstApi/list.do?menuNo=700052',
    '적금': 'https://finlife.fss.or.kr/finlife/api/fdrmEntyApi/list.do?menuNo=700053',
    '연금저축_이관안내': 'https://finlife.fss.or.kr/finlife/api/anntySvingsApi/list.do?menuNo=700054',
    '주택담보대출': 'https://finlife.fss.or.kr/finlife/api/houseMrtgApi/list.do?menuNo=700055',
    '전세자금대출': 'https://finlife.fss.or.kr/finlife/api/lfstsFundsApi/list.do?menuNo=700056',
    '개인신용대출': 'https://finlife.fss.or.kr/finlife/api/indvlCrdtApi/list.do?menuNo=700057',
    '개인사업자대출': 'https://finlife.fss.or.kr/finlife/api/indvlBusiApi/list.do?menuNo=700075',
    '연금저축_현행상품별': 'https://www.fss.or.kr/fss/lifeplan/devlopGuide/listInfo4.do?menuNo=201053',
    '연금저축_보험': 'https://www.fss.or.kr/fss/lifeplan/devlopGuide/listInfo3.do?menuNo=201053',
}
terms = ['spcl_cnd','join_member','etc_note','mtrt_int','join_way','loan_inci_expn',
         'erly_rpay_fee','dly_rate','loan_lmt','spcl_rate','loan_limit','join_deny',
         'loan_term','use_way','feeType','guarantees','sells','reserve','earnRate',
         'feeRate','publishedInterestRate','guaranteedInterestRate','이관','수수료', '이전']

if len(sys.argv)>1:
    sys.path.insert(0,sys.argv[1])
    import tiktoken
    encoder=tiktoken.get_encoding('o200k_base')
else:
    encoder=None

field_sets = {
    '정기예금':['spcl_cnd','join_member','etc_note','mtrt_int','join_way'],
    '적금':['spcl_cnd','join_member','etc_note','mtrt_int','join_way'],
    '주택담보대출':['join_way','loan_inci_expn','erly_rpay_fee','dly_rate','loan_lmt'],
    '전세자금대출':['join_way','loan_inci_expn','erly_rpay_fee','dly_rate','loan_lmt'],
    '개인신용대출':['join_way'],
    '개인사업자대출':['join_way','use_way','loan_limit','loan_limit_detl','join_deny','join_deny_detl','spcl_rate','loan_term','erly_rpay_fee','loan_inci_expn','dly_rate'],
}


def fetch(item):
    name, url = item
    try:
        response = requests.get(url, timeout=18)
        response.raise_for_status()
        html = response.content.decode('utf-8', errors='replace')
        parser = TableReader()
        parser.feed(html)
        matched = [row for row in parser.rows if any(t in ' '.join(row) for t in terms)]
        title = re.search(r'<title>(.*?)</title>',html,re.S)
        text = re.sub(r'\s+',' ',' '.join(parser.text))
        transfer = []
        for term in ['이관','이전']:
            pos=text.find(term)
            if pos>=0: transfer.append(text[max(0,pos-100):pos+400])
        sample_stats=[]
        for found in re.finditer(r'<textarea\b[^>]*>(.*?)</textarea>',html,re.S|re.I):
            sample=html_module.unescape(found.group(1)).strip()
            try:
                value=json.loads(sample)
                if not isinstance(value,dict) or not isinstance(value.get('result'),dict): continue
                res=value['result']
                base=res.get('baseList',[])
                options=res.get('optionList',[])
                selected=[{'id':i,**{f:r.get(f) for f in field_sets.get(name,[])}} for i,r in enumerate(base)]
                canonical=lambda x: json.dumps(x,ensure_ascii=False,separators=(',',':'))
                stats={'example_sha256':hashlib.sha256(sample.encode('utf-8')).hexdigest(),
                       'base_count':len(base),'option_count':len(options),
                       'months':sorted({r.get('dcls_month','') for r in base}),
                       'selected_fields':field_sets.get(name,[])}
                if encoder:
                    stats.update({'full_json_tokens':len(encoder.encode(canonical(value))),
                                  'selected_fields_tokens':len(encoder.encode(canonical(selected))),
                                  'selected_records_tokens_sum':sum(len(encoder.encode(canonical(r))) for r in selected)})
                sample_stats.append(stats)
            except (ValueError,TypeError): pass
        return {'name':name,'url':url,'status':response.status_code,
                'title':title.group(1).strip() if title else None,
                'matching_table_rows':matched, 'transfer_text':transfer,
                'all_table_row_count':len(parser.rows), 'public_json_examples':sample_stats}
    except Exception as error:
        return {'name':name,'url':url,'error':str(error)}


if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(fetch, pages.items()))
    examples=[s for r in results for s in r.get('public_json_examples',[])]
    totals={key:sum(s.get(key,0) for s in examples) for key in ['base_count','option_count','full_json_tokens','selected_fields_tokens']}
    report = {'checked_date_kst':'2026-11-24','scope':'Public documentation, not authenticated live product data',
              'example_totals':totals,'pages':results}
    Path(__file__).with_name('finlife-api-spec-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps([{k:v for k,v in r.items() if k in ['name','status','error','public_json_examples']} for r in results],ensure_ascii=False,indent=2))
