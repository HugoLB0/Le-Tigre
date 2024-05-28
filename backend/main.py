

# main version should contain the flask that will be able to accept the request
from flask import Flask, request, jsonify
import asyncio
import logging
import json
import utils
import utils_llm
from dotenv import load_dotenv
import os 
import time
import threading

load_dotenv()
app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(filename)s - %(funcName)s: %(message)s")


prompt_storage = None 
image_storage = None

async def process_image_data(image):

    yolo_model_runner = utils.RunModel(YOLO_MODEL_OB)
    ocr_model_runner = utils.RunAPi(GOOGLE_VISION_CLIENT)

    start_time = asyncio.get_event_loop().time() # time mesure start

    yolo_task = asyncio.create_task(yolo_model_runner.run_yolo_model(image))
    ocr_task = asyncio.create_task(ocr_model_runner.run_ocr(image))

    yolo_out, ocr_out = await asyncio.gather(yolo_task, ocr_task)

    end_time = asyncio.get_event_loop().time() # End time measurement
    processing_time = end_time - start_time

    print(f"Processing Time: {processing_time:.2f} seconds")
    return {
        'ocr_out': json.dumps(ocr_out, default=str),
        'yolo_out': json.dumps(yolo_out, default=str),
        #'processing_time': f"{processing_time:.2f} seconds"
    }


@app.route('/prompt', methods=['POST'])
async def capture_text():
    global prompt_storage
    try:
        print("Received a POST request")

        # Log request headers and body
        print("Headers:", request.headers)
        print("Form data:", request.form)
        print("Files:", request.files)

        prompt_ = request.args.get('prompt')
        prompt_storage = prompt_
        response = {
            "message": "Prompt received successfully",
            "prompt": prompt_
        }

        return jsonify(response), 200

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500
    

@app.route('/image', methods=['POST'])
async def capture_frame():
    global image_storage
    try:
        print("Received a POST request")

        # Log request headers and body
        print("Headers:", request.headers)
        print("Form data:", request.form)
        print("Files:", request.files)

        if 'image' not in request.files:
            print("No image file received")
            return jsonify({"error": "No image file received"}), 400
        image_file = request.files['image']

        image_filename = f"received_frame_{int(time.time())}.jpg"
        image_path = os.path.join('received_images', image_filename)
        image_file.save(image_path)

        image_storage = image_path

        print(f"Image saved to: {image_path}")

        response = {
            "message": "Image received successfully",
            "image_path": image_path
        }

        return jsonify(response), 200
    
    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


# tests
@app.route('/fetch_data', methods=['GET'])
async def chat_():
    global prompt_storage, image_storage, llm_response_final
    
    text_input, image_path = prompt_storage, image_storage
    response = await process_image_data(image_path)

    # call the LLM
    logging.info(f"entering image LLM chain")
    llm_image_instance = utils_llm.LLM_image()
    llm_image_chain = llm_image_instance.load_model()

    llm_final_res = ""

    async for llm_response in llm_image_instance.execute_llm(json.dumps(response), llm_image_chain):
    #async for llm_response in llm_image_instance.execute_llm(input__, llm_image_chain):
        print(llm_response, end="", flush=True)
        llm_final_res += llm_response
    print()

    llm_input = {
        'user_input': text_input,
        'image_description': llm_final_res
    }

    print(llm_input)

    logging.info(f"entering main LLM chain")
    llm_main_instance = utils_llm.LLM_main()
    llm_main_chain = llm_main_instance.load_model()
    
    llm_response_final = ""


    async for llm_response in llm_main_instance.execute_llm(json.dumps(llm_input), llm_main_chain):
    #async for llm_response in llm_main_instance.execute_llm(input__, llm_main_chain):
        print(llm_response, end="", flush=True)
        llm_response_final += llm_response
    
    
        
    print(f"final: {llm_response_final}")
    return  jsonify({
                "llm_response": llm_response_final
            }), 200




YOLO_MODEL_OB = utils.ModelLoader().load_yolo_model()
logging.debug(f"yolo model loaded")
GOOGLE_VISION_CLIENT = utils.APIauth().google_vision_auth()
logging.debug(f"authenticated google vision")
LLM_IMAGE_CHAIN = utils_llm.LLM_image().load_model()
logging.debug(f"image LLM chain loaded")
LLM_MAIN_CHAIN = utils_llm.LLM_main().load_model()
logging.debug(f"main LLM chain loaded")




def listen_():
    while True:
        asyncio.run(chat_())

if __name__ == '__main__':
    threading.Thread(target=listen_, daemon=True).start()  # Start the listen_ function in a separate thread
    app.run(host='0.0.0.0', debug=True, use_reloader=False, port=3333)



"""
if __name__ == '__main__':
    logging.debug(f"loading models")

    YOLO_MODEL_OB = ModelLoader().load_yolo_model()
    # test with an image
    logging.debug(f"yolo model loaded")

    app.run(debug=True)


    
"""

