import argparse
from datetime import datetime
from subprocess import call

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate post or page.")
    parser.add_argument("type",  type=str, help="post or page")
    parser.add_argument("title", type=str, help="title of post or page", nargs="+")

    args = parser.parse_args()
    
    if args.type == "post":
        date = datetime.now().strftime("%Y-%m-%d")
        if len(args.title) > 1:
            title = "-".join(args.title)
        else:
            title = args.title[0]
        call(f"hugo new content/posts/{date}-{title}.md", shell=True)
    else:
        raise NotImplementedError()
