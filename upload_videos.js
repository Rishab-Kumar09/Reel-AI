const { initializeApp } = require('firebase/app');
const { getStorage, ref, uploadBytes, getDownloadURL } = require('firebase/storage');
const fs = require('fs');
const path = require('path');

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCP25_SShUfmIqonGICX4j-YYB81C99BDA",
  authDomain: "reel-ai-8132d.firebaseapp.com",
  projectId: "reel-ai-8132d",
  storageBucket: "reel-ai-8132d.firebasestorage.app",
  messagingSenderId: "403328203757",
  appId: "1:403328203757:web:6111f04409a3b4a97a85e4",
  measurementId: "G-87E1LFSJL2"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const storage = getStorage(app);

async function uploadVideo(filePath) {
  try {
    const fileName = path.basename(filePath);
    const storageRef = ref(storage, 'videos/' + fileName);
    
    console.log(`Uploading ${fileName}...`);
    const fileData = fs.readFileSync(filePath);
    await uploadBytes(storageRef, fileData);
    
    const downloadURL = await getDownloadURL(storageRef);
    console.log(`${fileName} uploaded successfully!`);
    console.log(`Download URL: ${downloadURL}`);
    
    return downloadURL;
  } catch (error) {
    console.error(`Error uploading ${filePath}:`, error);
    throw error;
  }
}

async function uploadAllVideos() {
  const videoDir = './sample_videos';
  const files = fs.readdirSync(videoDir);
  
  for (const file of files) {
    if (file.endsWith('.mp4')) {
      const filePath = path.join(videoDir, file);
      await uploadVideo(filePath);
    }
  }
}

uploadAllVideos().catch(console.error); 