import pandas as pd
from os.path import join
import httpcore
setattr(httpcore, 'SyncHTTPTransport', 'AsyncHTTPProxy')
from config import DATA_DIR
from googletrans import Translator
translator = Translator()
import time


if __name__ == "__main__":
    df = pd.read_csv(join(DATA_DIR,'unique_rules_joined_26032024.csv'))
    df['translated_rule'] = ''

    for i in range(df.shape[0]):
        try:
            translation = translator.translate(df['rule'][i]).text
            df['translated_rule'][i] = translation
        except Exception as e:
            print(e)
            time.sleep(10)
            continue

    df.to_csv(join(DATA_DIR, 'unique_rules_joined_translated_26032024.csv'),index=False)