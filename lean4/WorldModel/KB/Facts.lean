/-
  WorldModel.KB.Facts
  Named entity instances and ground relation facts.
-/
import WorldModel.KB.Relations

-- Humans
def jose    : Human "Jose"    := .mk "Jose"
def rick    : Human "Rick"    := .mk "Rick"
def allen   : Human "Allen"   := .mk "Allen"
def matthew : Human "Matthew" := .mk "Matthew"

-- Languages
def english : Language "English" := .mk "English"
def spanish : Language "Spanish" := .mk "Spanish"
def french  : Language "French"  := .mk "French"

-- Cities
def valencia : City "Valencia" := .mk "Valencia"
def london   : City "London"   := .mk "London"
def nice     : City "Nice"     := .mk "Nice"
def paris    : City "Paris"    := .mk "Paris"

-- Clinics
def valClinic    : Clinic "ValClinic"    := .mk "ValClinic"
def niceClinic   : Clinic "NiceClinic"   := .mk "NiceClinic"
def parisClinic  : Clinic "ParisClinic"  := .mk "ParisClinic"
def londonClinic : Clinic "LondonClinic" := .mk "LondonClinic"

-- Clinical trials
def ourTrial : ClinicalTrial "OurTrial" := .mk "OurTrial"

-- Ground relation facts

def jose_is_patient      : hasRole jose .Patient        := .mk
def rick_is_admin        : hasRole rick .Administrator  := .mk
def allen_is_clinician   : hasRole allen .Clinician     := .mk
def matthew_is_clinician : hasRole matthew .Clinician   := .mk

def jose_speaks_spanish    : speaks jose spanish    := .mk
def rick_speaks_english    : speaks rick english    := .mk
def allen_speaks_english   : speaks allen english   := .mk
def allen_speaks_spanish   : speaks allen spanish   := .mk
def matthew_speaks_english : speaks matthew english := .mk
def matthew_speaks_french  : speaks matthew french  := .mk

def jose_lives_valencia : lives jose valencia := .mk

def rick_assigned_london   : assigned rick londonClinic    := .mk
def allen_assigned_val     : assigned allen valClinic      := .mk
def matthew_assigned_nice  : assigned matthew niceClinic   := .mk

def valClinic_in_valencia  : isIn valClinic valencia    := .mk
def niceClinic_in_nice     : isIn niceClinic nice       := .mk
def parisClinic_in_paris   : isIn parisClinic paris     := .mk
def londonClinic_in_london : isIn londonClinic london   := .mk
