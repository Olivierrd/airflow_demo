
def wait(**kwargs):
    import time
    seconds = kwargs["dag_run"].conf.get("define_variable", "10")
    time.sleep(int(seconds))

def copy(prefixes):
    import time
    for i in prefixes:
        print(i)
        time.sleep(1)

def create_table(prefixes):
    import time
    for i in prefixes:
        print(i)
        time.sleep(1)

def convert(prefixe):
    import time
    print(prefixe)
    time.sleep(2)


def notify(title, text):
    text = text.replace("\n", "<br>")
    print(f'{title}\n{text}')
