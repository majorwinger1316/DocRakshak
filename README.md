This iOS application, developed using Swift, leverages Optical Character Recognition (OCR) technology to identify and extract text from images. Once the text is extracted, the application utilizes a custom Machine Learning model to detect Personally Identifiable Information (PII), such as names, addresses, Aadhaar numbers, and other sensitive data.

Upon identifying the PII, the app prompts the user with the option to mask the detected information. If the user consents, the application automatically masks the PII, ensuring data privacy and protection. The processed image is then converted into a .txt format for further use or storage.

This solution emphasizes both data security and user control over sensitive information.

Developed using Xcode with Storyboard (UIKit).
Utilizes VisionKit for image recognition.
Employs Vision to convert images into text.
Supports document fetching from phone memory using MobileCoreServices and PDFKit.
Custom PII detection performed using a Machine Learning model trained on a synthetic dataset through Apple's CreateML.
