# validate.py
from InquirerPy import inquirer

def main():
    result = inquirer.text(
        message="Apply? (Y/n): ",
        validate=lambda x: x.upper() in ["Y", "N"],
    ).execute()
    return 0 if result.upper() == "Y" else 1

if __name__ == "__main__":
    exit(main())