prompt = """
You are an AI that analyzes the rules of a Mastodon instance.
Your task is to determine, for each predefined category, whether the provided text expresses any rule, requirement, guideline, or information relevant to that category.

Input
You will receive:
1. A list of categories
2. A block of text containing the instance’s rules.

Output Requirements
For each category, output:
1 → if the text contains a rule, guideline, recommendation, or information belonging to that category.
0 → if the category is not mentioned or not implied.
This includes prohibitions, requirements, recommendations, and informational rules — not only bans.

Decision Rules
1) CW-Enabled Categories
Some categories have both a prohibition version and a content warning version.
For these categories, apply the following:
1. If the content is prohibited
  → Set the main category to 1
  → Set the corresponding category-specific CW field to 0
2. If the content is allowed but must be tagged (CW required)
  → Set the main category to 0
  → Set the category-specific CW field to 1
3. If neither applies
  → Both fields remain 0
4. General CW rule
If the text describes a general policy requiring content warnings (not tied to a specific content type), then set:
  → "cw_general": 1
Otherwise 
  → "cw_general": 0

2) Specificity Rule (Very Important)
If a rule matches more than one category:
Use the most specific category whenever possible.
If a specific category matches, set the broad category to 0 unless the broad category is explicitly mentioned in the text.

Example (violence hierarchy)
animal_cruelty is a specific subtype of violence.
violence is broader and typically refers to violence involving humans or non-specific violence.
So:
"No violent content involving animals" → "animal_cruelty": 1, "violence": 0
"No violence allowed" → "violence": 1
"No violence of any kind, including against animals" → "violence": 1 and optionally "animal_cruelty": 1

3) Important Note About Allowed Content
You must not treat statements that merely allow content as restrictions.
Examples:
"NSFW content is allowed" → "nsfw" = 0, "nsfw_cw" = 0
"Violence is permitted but discouraged" → output 0 unless explicitly restricted or CW-tagged
"Advertising is allowed" → "advertising": 0

4) Examples of correct classifications
"Be kind to others" -> "be_nice": 1
"Follow the code of conduct" -> "codes_conduct": 1
"Pornography is forbidden" -> "porn": 1
"Pornography must be tagged" -> "porn": 0, "porn_cw": 1
"Pornography is allowed" -> all porn fields = 0
"Off-topic posts will be removed" -> "spam": 1

Output Format
Return only valid JSON, with each category (and each category-CW field, plus cw_general) as keys and 0 or 1 as values.

Example (illustrative only):
{
  "CSAM": 1,
  "advertising": 0,
  "adult_content": 1,
  "adult_content_cw": 0,
  "ai_generated": 0,
  "animal_cruelty": 0,
  "automated_tools_bots": 1,
  "be_nice": 1,
  "block_report_mute": 0,
  "codes_conduct": 1,
  "consequences_moderation": 1,
  "copyright_piracy_credit": 0,
  "crypto": 0,
  "cw_general": 1,
  "dont_be_dick": 1,
  "harassment": 1,
  "hate_speech": 1,
  "illegal": 1,
  "impersonation": 0,
  "incitement_violence": 0,
  "language_specific": 0,
  "misinfo": 0,
  "nazis": 1,
  "nsfw": 0,
  "nsfw_cw": 1,
  "politics": 0,
  "politics_cw": 0,
  "privacy": 1,
  "private_no_reg": 0,
  "registration_requirements": 1,
  "religion": 0,
  "scrape_model_training": 0,
  "spam": 1,
  "spoilers": 0,
  "spoilers_cw": 0,
  "violence": 1,
  "violence_cw": 0
}
Do not include explanations or additional text.


Categories:
    • advertising: Bans advertising or commercial promotion, including, but not limited to, self promotion.
    • ai_generated: Bans AI generated content.
    • animal_cruelty: Prohibits bestiality, sexual or violent content involving animals.
    • automated_tools_bots: Prohibits or eventually prohibits automation, bots, or scrapers or states that they have to be marked.
    • be_nice: Encourages general kindness, excellence and respectful interaction among users, e.g. by promoting decency or common sense.
    • block_report_mute: Encourages self-moderation by the users by recommending the use of blocking, reporting, or muting tools for moderation.
    • codes_conduct: Refers to adherence to a specific code of conduct such as, but not limited to, guidelines (e.g. of another instance or platform), terms of service, the Mastodon covenant, or referral to linked rules. Ignore reference to international laws. 
    • consequences_moderation: States that rule violations may lead to moderation actions, possibly detailing those actions.
    • copyright_piracy_credit: Bans piracy or requires proper credit and licensing.
    • crypto: Bans cryptocurrency or NFT promotion.
    • CSAM: Bans child sexual abuse material in any form.
    • cw_general: Encourages or requires general use of content warnings.
    • dont_be_dick: Prohibits rude, provocative or inconsiderate behavior such as trolling; usually tells people not to be a dick/jerk/asshole.
    • harassment: Prohibits bullying, intimidation, humiliation or targeted harassment of others, including but not limited to offensive content or dogpiling. 
    • hate_speech: Bans content that promotes hatred or discrimination against groups or individuals based on the perceived belonging of a certain characteristic, e.g., but not limited to, racism, sexism, transphobia or antisemitism.
    • illegal: Prohibits illegal activity or content under applicable law.
    • incitement_violence: Prohibits calls for violence or encouragement of harm.
    • language_specific: Expects or recommends users to use a certain language or a certain group of languages.
    • misinfo: Bans misinformation, disinformation, propaganda, conspiracy content or defamation.
    • nazis: Bans fascist and nationalist content.
    • nsfw: Bans not safe for work or sensitive content in the broadest sense.
    • nsfw_cw: Not safe for work or sensitive content in the broadest sense is per se allowed, but must be marked with a content warning.
    • politics: Bans political discussions, political activism or (politically) controverse topics.
    • politics_cw: Political discussions, political activism or (politically) controverse topics are per se allowed, but must be marked with a content warning.
    • adult_content: Bans adult content, such as pornography, sexually explicit content or nudity.
    • adult_content_cw: Adult content, such as pornography, sexually explicit content or nudity, is per se allowed, but must be marked with a content warning.
    • privacy: Prohibits sharing others’ private or personal information without their consent, including doxxing.
    • private_no_reg: Marks the instance as, for example, but not limited to, private, personal, single-user, closed to new registrations or as a test or development server.
    • registration_requirements: Specifies the requirements for registration, e.g., but not limited to a minimum age, a certain email provider, an invitation or identity verification.
    • religion: Bans religious promotion or debate.
    • scrape_model_training: Prohibits data scraping or use for AI model training.
    • sensitive_cw: Sensitive content is per se allowed, but must be marked with a content warning.
    • spam: Prohibits spam, excessive promotion, or repetitive posts.
    • spoilers: Bans story or media spoilers.
    • spoilers_cw: Story or media spoilers are per se allowed, but must be marked with a content warning.
    • violence: Prohibits violent content or glorification of violence.
    • violence_cw: Violent content or glorification of violence is per se allowed, but must be marked with a content warning.
    • impersonation: Prohibits pretending to be another person or organization.

Here comes the rule: 
"""