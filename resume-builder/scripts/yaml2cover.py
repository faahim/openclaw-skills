#!/usr/bin/env python3
"""Generate cover letter from resume YAML."""
import sys
import yaml
from datetime import date

input_file = sys.argv[1]
company = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "the company"
role = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else "the position"

with open(input_file) as f:
    data = yaml.safe_load(f)

today = date.today().strftime("%B %d, %Y")
name = data.get('name', 'Name')
contact = data.get('contact', {})
summary = data.get('summary', '')

print(f"""# Cover Letter

**{name}**
{contact.get('email', '')} | {contact.get('phone', '')} | {contact.get('location', '')}

{today}

Dear Hiring Manager,

I am writing to express my interest in the {role} position at {company}. {summary}

I am excited about the opportunity to bring my experience to {company} and contribute to your team's success.

Thank you for considering my application. I look forward to discussing how my background aligns with your needs.

Sincerely,
{name}
""")
