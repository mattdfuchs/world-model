# Refinement by Substitution

A Box has an input Product type and an output Sum type, where each branch is a Product type. It can be abstract or concrete.
If abstract, it can be substituted by a network of Boxes with the same inputs and outputs. In the end, we want a network of
concrete Boxes with types lined up correctly.

Since each output is a disjunction of conjunctions, each output can be named with two numbers - the index of the conjunct and
index of the disjunct. As each input is just a Product, it can be named with the indices of the projections. This way we can tie
together inputs and outputs. We can tie together elements of two disjuncts from the same Box by unifying them, so that whichever
disjunct comes from a Box, overlapping elements of the product can go into the same successor Box.

Likewise we need a way of ensuring strings from different disjuncts don't get improperly mixed. For a later version.

Consider the first meeting of a Patient in a Clinical Trial. The outcome is either:

- Success:
  - Signed consent form
  - Various measurements
    - Heart rate
    - Blood pressure
    - Temperature
    - VO2Max (just want something that's not easy to get, requiring some search)
  - Inoculated patient
- Failure
  - Patient
  - Refusal form (some explanation)

So the Box is something like

```mermaid
graph TB
    In[" "] -->|"Patient"| IM["Initial Meeting Layout - abstract"]
    IM ==>|"Inoculated Patient"| Out1a[" "]
    IM ==>|"Signed Form"| Out1b[" "]
    IM ==>|"Heart Rate"| Out1c[" "]
    IM ==>|"Blood Pressure"| Out1d[" "]
    IM ==>|"Temp"| Out1e[" "]
    IM ==>|"VO2Max"| Out1f[" "]
    IM -.->|"Informed Patient"| Out2a[" "]
    IM -.->|"Refusal Form"| Out2b[" "]
    style In fill:none,stroke:none
    style Out1a fill:none,stroke:none
    style Out1b fill:none,stroke:none
    style Out1c fill:none,stroke:none
    style Out1d fill:none,stroke:none
    style Out1e fill:none,stroke:none
    style Out1f fill:none,stroke:none
    style Out2a fill:none,stroke:none
    style Out2b fill:none,stroke:none
```

This obviously has nothing to perform any of the needed procedures, so we substitute

```mermaid
graph TB
    In[" "] -->|"Patient"| Consent
    subgraph Initial Meeting
        Consent ==>|"Informed Patient"| HR["Heart Rate"]
        Consent ==>|"Signed Form"| OutSF[" "]
        Consent -.->|"Informed Patient"| OutRA[" "]
        Consent -.->|"Refusal Form"| OutRB[" "]
        HR ==>|"Informed Patient"| BP["Blood Pressure"]
        HR ==>|"Measurement Heart Rate"| OutHR[" "]
        BP ==>|"Informed Patient"| Temp
        BP ==>|"Measurement Blood Pressure"| OutBP[" "]
        Temp ==>|"Informed Patient"| VO["VO2Max"]
        Temp ==>|"Measurement Temp"| OutTM[" "]
        VO ==>|"Informed Patient"| Inoculate
        VO ==>|"Measurement VO2Max"| OutVO[" "]
        Inoculate ==>|"Inoculated Patient"| OutIP[" "]
    end
    style In fill:none,stroke:none
    style OutSF fill:none,stroke:none
    style OutHR fill:none,stroke:none
    style OutBP fill:none,stroke:none
    style OutTM fill:none,stroke:none
    style OutVO fill:none,stroke:none
    style OutIP fill:none,stroke:none
    style OutRA fill:none,stroke:none
    style OutRB fill:none,stroke:none
```
