import React, { useEffect, useRef, useState } from "react";

export default function DogDetectPage() {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const [streamActive, setStreamActive] = useState(false);
  const [loadingModel, setLoadingModel] = useState(false);
  const [predictions, setPredictions] = useState([]);
  const [model, setModel] = useState(null);

  useEffect(() => {
    return () => stopStream();
  }, []);

  async function loadModel() {
    if (model) return model;
    setLoadingModel(true);
    const tf = await import("@tensorflow/tfjs");
    const mobilenet = await import("@tensorflow-models/mobilenet");
    const m = await mobilenet.load({ version: 2, alpha: 1.0 });
    setModel(m);
    setLoadingModel(false);
    return m;
  }

  async function startCamera() {
    try {
      const s = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false,
      });
      if (videoRef.current) {
        videoRef.current.srcObject = s;
        await videoRef.current.play();
        setStreamActive(true);
      }
    } catch (e) {
      console.error(e);
      alert("Could not access camera: " + e.message);
    }
  }

  function stopStream() {
    const v = videoRef.current;
    if (v && v.srcObject) {
      const tracks = v.srcObject.getTracks();
      tracks.forEach((t) => t.stop());
      v.srcObject = null;
    }
    setStreamActive(false);
  }

  async function captureAndClassify() {
    const m = await loadModel();
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext("2d");
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // stop camera after taking a picture
    stopStream();

    const img = canvas;
    try {
      const preds = await m.classify(img);
      setPredictions(preds);
    } catch (err) {
      console.error(err);
      alert("Classification failed: " + err.message);
    }
  }

  return (
    <div className="p-6 max-w-3xl mx-auto">
      <h2 className="text-2xl font-semibold mb-4">
        Dog Species Demo (single photo)
      </h2>

      <div className="mb-4">
        {!streamActive ? (
          <button
            onClick={startCamera}
            className="bg-amber-700 text-white px-4 py-2 rounded"
          >
            Open Camera
          </button>
        ) : (
          <button
            onClick={stopStream}
            className="bg-gray-600 text-white px-4 py-2 rounded"
          >
            Close Camera
          </button>
        )}
        <button
          onClick={captureAndClassify}
          disabled={!streamActive || loadingModel}
          className="ml-3 bg-amber-500 text-white px-4 py-2 rounded"
        >
          Take Photo & Classify
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white rounded shadow p-2">
          <video
            ref={videoRef}
            className="w-full h-auto bg-black"
            playsInline
            muted
          />
        </div>

        <div className="bg-white rounded shadow p-2">
          <canvas ref={canvasRef} className="w-full h-auto bg-gray-100" />
        </div>
      </div>

      <div className="mt-4 bg-white rounded shadow p-4">
        <h3 className="font-semibold mb-2">Predictions</h3>
        {loadingModel && <div>Loading model…</div>}
        {!loadingModel && predictions.length === 0 && (
          <div>No predictions yet.</div>
        )}
        <ul>
          {predictions.map((p, i) => (
            <li key={i} className="py-1">
              <strong>{p.className}</strong> —{" "}
              {(p.probability * 100).toFixed(1)}%
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
