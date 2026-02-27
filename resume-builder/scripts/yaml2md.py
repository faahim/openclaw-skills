#!/usr/bin/env python3
"""Convert resume YAML to Markdown."""
import sys
import json
import yaml

input_file = sys.argv[1]
sections_filter = sys.argv[2].split(",") if len(sys.argv) > 2 and sys.argv[2] else []
skills_filter = [s.strip() for s in sys.argv[3].split(",")] if len(sys.argv) > 3 and sys.argv[3] else []

with open(input_file) as f:
    data = yaml.safe_load(f)

lines = []

# Header
lines.append(f"# {data.get('name', 'Name')}")
if data.get('title'):
    lines.append(f"**{data['title']}**\n")

# Contact
contact = data.get('contact', {})
contact_parts = []
if contact.get('email'): contact_parts.append(contact['email'])
if contact.get('phone'): contact_parts.append(contact['phone'])
if contact.get('location'): contact_parts.append(contact['location'])
if contact.get('linkedin'): contact_parts.append(contact['linkedin'])
if contact.get('github'): contact_parts.append(contact['github'])
if contact.get('website'): contact_parts.append(contact['website'])
if contact_parts:
    lines.append(" | ".join(contact_parts) + "\n")

# Summary
if data.get('summary') and (not sections_filter or 'summary' in sections_filter):
    lines.append("---\n")
    lines.append(f"{data['summary']}\n")

# Experience
if data.get('experience') and (not sections_filter or 'experience' in sections_filter):
    lines.append("## Experience\n")
    for job in data['experience']:
        location = f" — {job['location']}" if job.get('location') else ""
        lines.append(f"### {job['role']} | {job['company']}{location}")
        lines.append(f"*{job['dates']}*\n")
        for h in job.get('highlights', []):
            lines.append(f"- {h}")
        lines.append("")

# Education
if data.get('education') and (not sections_filter or 'education' in sections_filter):
    lines.append("## Education\n")
    for edu in data['education']:
        gpa = f" (GPA: {edu['gpa']})" if edu.get('gpa') else ""
        lines.append(f"### {edu['degree']} | {edu['institution']}{gpa}")
        lines.append(f"*{edu['dates']}*\n")
        for h in edu.get('highlights', []):
            lines.append(f"- {h}")
        lines.append("")

# Skills
if data.get('skills') and (not sections_filter or 'skills' in sections_filter):
    lines.append("## Skills\n")
    skills = data['skills']
    if isinstance(skills, dict):
        for category, items in skills.items():
            if isinstance(items, list):
                if skills_filter:
                    items = [i for i in items if i in skills_filter]
                    if not items:
                        continue
                lines.append(f"**{category.replace('_', ' ').title()}:** {', '.join(items)}")
            else:
                lines.append(f"**{category.replace('_', ' ').title()}:** {items}")
        lines.append("")
    elif isinstance(skills, list):
        filtered = skills if not skills_filter else [s for s in skills if s in skills_filter]
        lines.append(", ".join(filtered) + "\n")

# Certifications
if data.get('certifications') and (not sections_filter or 'certifications' in sections_filter):
    lines.append("## Certifications\n")
    for cert in data['certifications']:
        date = f" ({cert['date']})" if cert.get('date') else ""
        lines.append(f"- **{cert['name']}**{date}")
    lines.append("")

# Projects
if data.get('projects') and (not sections_filter or 'projects' in sections_filter):
    lines.append("## Projects\n")
    for proj in data['projects']:
        url_str = proj.get('url', '')
        url = f" — [{url_str}](https://{url_str})" if url_str else ""
        lines.append(f"- **{proj['name']}**{url}: {proj.get('description', '')}")
    lines.append("")

print("\n".join(lines))
