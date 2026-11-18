#!/usr/bin/env python3
"""Export manuscript tables and TikZ diagrams from freshly fitted results; no compilation."""
import csv,re
from pathlib import Path
root=Path(__file__).resolve().parent
out=root/'results/paper_outputs';out.mkdir(exist_ok=True)
def read(name):
 with (root/'results'/name).open() as f:return list(csv.DictReader(f))
def write(name,headers,rows):
 with (out/(name+'.csv')).open('w') as f:
  w=csv.writer(f);w.writerow(headers);w.writerows(rows)
 with (out/(name+'.md')).open('w') as f:
  f.write('| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n')
  for row in rows:f.write('| '+' | '.join(map(str,row))+' |\n')
def ci(r,e='estimate',lo='ci.lower',hi='ci.upper'):
 return f'{float(r[e]):.3f} [{float(r[lo]):.3f}, {float(r[hi]):.3f}]'
labels={'happiness':'Happiness','lifesat':'Life satisfaction','purpose':'Purpose in life'}
a=read('paper_checks/temporal_robustness.csv')
write('table_1_annual',['Scale','Outcome','Estimate [95% CI]','Observations','Countries'],
 [[r['level'],labels[r['outcome']],ci(r,'beta','ci_low','ci_high'),r['n_observations'],r['n_countries']] for r in a])
sem=read('community_sem/sem_paths.csv');static=read('regional_static/sem_paths.csv')
for name,rows in [('table_2_country_sem',[r for r in sem if r['level']=='Country']),('table_3_region_sem',[r for r in sem if r['level']=='NUTS1']),('table_6_static_sem',static)]:
 ix={r['label']:r for r in rows}
 vals=[['a']+[ci(ix['a'])]*3]
 for prefix,label in [('b_','b_k'),('c_',"c'_k"),('indirect_','a b_k'),('total_','c_k')]:vals.append([label]+[ci(ix[prefix+k]) for k in 'hlp'])
 write(name,['Path','Happiness','Life satisfaction','Purpose in life'],vals)
cy=read('country_year_robustness/coefficients.csv')
rows=[]
for v,label in labels.items():
 cells=[next(r for r in cy if r['outcome']==v and r['sample']=='outcome_specific' and r['design']==design) for design in ['country_linear_trends','country_year_fe']]
 rows.append([label]+[ci(r,'beta','ci_low','ci_high') for r in cells])
write('table_4_country_year',['Outcome','Regional baseline','Country-by-year effects'],rows)
a=read('regional_static/association.csv')
write('table_5_regional_averages',['Outcome','Estimate [95% CI]','Regions','Countries'],[[labels[r['outcome']],ci(r,'beta','ci_low','ci_high'),r['n_regions'],r['n_countries']] for r in a])
c=read('paper_checks/outcome_contrasts.csv')
write('table_7_contrasts',['Design','Purpose minus happiness','Purpose minus life satisfaction'],[[design]+[ci(next(r for r in c if r['design']==design and r['comparison']=='purpose minus '+v),'difference','ci_low','ci_high') for v in ['happiness','lifesat']] for design in dict.fromkeys(r['design'] for r in c)])
latent=read('latent_multilevel_sem/diagnostics.csv')
write('table_S1_latent_diagnostics',['Specification','Negative variances','At zero','CFI','RMSEA'],[[r['specification'],r['negative_variances'],r['boundary_variances'],f"{float(r['cfi']):.3f}",f"{float(r['rmsea']):.3f}"] for r in latent])
# The hypothesis assessment is an interpretation of directional confidence intervals.
support=lambda rows,lo:sum(float(r[lo])>0 for r in rows)
hyp=[['H1','Yes' if support([r for r in read('paper_checks/temporal_robustness.csv') if r['level']=='Country'],'ci_low')==3 else 'Review'],
 ['H2','Partial' if support([r for r in sem if r['level']=='Country' and r['label'].startswith('indirect_')],'ci.lower')==2 else 'Review'],
 ['H1-Reg','Yes' if support([r for r in read('paper_checks/temporal_robustness.csv') if r['level']=='NUTS1'],'ci_low')==3 else 'Review'],
 ['H2-Reg','No (inconclusive)' if support([r for r in sem if r['level']=='NUTS1' and r['label'].startswith('indirect_')],'ci.lower')==0 else 'Review'],
 ['H3','Yes' if support(a,'ci_low')==3 else 'Review'],['H4','Partial' if support(c,'ci_low')==5 else 'Review']]
assert all(v!='Review' for _,v in hyp)
write('table_8_hypotheses',['Hypothesis','Support'],hyp)
for template in (root/'templates').glob('*.tex'):
 text=template.read_text();slug=template.stem
 if slug in ['country-paths','region-paths','static-paths']:
  rows=static if slug=='static-paths' else [r for r in sem if r['level']==('Country' if slug=='country-paths' else 'NUTS1')]
  ix={r['label']:r for r in rows};values=iter(float(ix[key]['estimate']) for k in 'hlp' for key in ['a','b_'+k,'c_'+k])
  text,n=re.subn(r"(\$(?:a|b_k|c'_k)=)[+-]\d+\.\d{3}(\$)",lambda m:m[1]+f'{next(values):+.3f}'+m[2],text)
  assert n==9
 (out/template.name).write_text(text)
print('Exported Tables 1–8, Table S1, and six TikZ figure fragments. No LaTeX compilation performed.')
