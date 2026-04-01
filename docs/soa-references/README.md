# SoA Reference Materials

Protocol PDFs downloaded from clinicaltrials.gov and academic papers for grounding the Type 2 SoA encoding.

## Academic Papers (SoA-H series)

- **SoA-H1**: Richardson & Genyn 2025, JMIR — Table 1 partial SoA matrix, graph-based attribute model
  https://pmc.ncbi.nlm.nih.gov/articles/PMC12583939/
- **SoA-H2**: Richardson 2024, JSCDM — Figure 1 annotated LZZT SoA, required characteristic attributes
  https://www.jscdm.org/article/id/266/
- **SoA-H3**: Kim et al. 2025 — automated SoA table generation
  https://pmc.ncbi.nlm.nih.gov/articles/PMC12167819/

## Protocol PDFs (SoA-P series)

| File | Trial | SoA starts at |
|------|-------|---------------|
| SoA-P1-COVACTA-tocilizumab.pdf | Tocilizumab COVID (NCT04320615) | p.77 |
| SoA-P2-Janssen-Ad26COV2S.pdf | Janssen vaccine (NCT04505722) | p.41 |
| SoA-P4-Pfizer-BNT162b2.pdf | Pfizer vaccine (NCT04368728) | p.41 |
| SoA-P5-Osimertinib-EGFR.pdf | Osimertinib NSCLC (NCT03653546) | p.9 |
| SoA-P9-FINEARTS-HF-finerenone.pdf | Finerenone HF (NCT04435626) | p.12 |
| SoA-P10-TJ301-UC.pdf | TJ301 ulcerative colitis (NCT03235752) | p.7 |

## Key Structural Patterns

Real SoAs are typed property graphs, not flat tables. Richardson (H1/H2) formalizes this:

- **Interaction nodes** (visits): timing, phase, modality, window, repeat pattern
- **Activity nodes** (procedures): category, requirements, outputs
- **Edges**: performs (interaction→activity, cell value), follows (interaction→interaction, transition), requires (activity→activity, dependency)

### Study phases across protocols

| Protocol | Phases |
|----------|--------|
| COVACTA | Screening → Baseline → Treatment (D1-2) → Follow-up (D3-28) → Completion |
| Janssen | Screening → Study Period → Long-term Follow-up → Exit |
| Pfizer | Screening → Vax 1 + follow-ups → Vax 2 + follow-ups → 6/12/24-month |
| Osimertinib | Screening → C1D1 → C2D1 onwards (repeating cycles) → Discontinuation → Follow-ups |
| FINEARTS-HF | Screening → Baseline → Monthly → Every 4 months → Up-titration → PD → EOS → PT |
| TJ301 UC | Run-in → Screening → Treatment (Q2W) → Safety Follow-up |

### Matrix cell values (not just boolean)

X (required), blank (N/A), Optional, ~10mL/~50mL (quantities), Daily/Continuous (frequencies), X^a/X^b (conditional footnotes), O/phone-icon (modality markers)

### Activity categories (recur across all protocols)

Initiation, Clinical assessments, Lab (local), Lab (central), Study intervention, Imaging, PRO/questionnaires, Safety monitoring

### Open-ended / repeating patterns (maps to nu-iteration)

- Osimertinib: "C2D1 onwards" every 3 weeks until progression
- FINEARTS: visits 7+ alternate on-site/phone every 2 months until EOS
- TJ301: Q2W treatment visits for 12 weeks
