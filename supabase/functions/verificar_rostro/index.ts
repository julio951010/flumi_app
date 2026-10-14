// Verifica que la selfie corresponde al mismo rostro que las fotos de perfil.
// Invocada desde la app (web) con { selfie: string, fotos: string[] } (URLs públicas).
//
// Requisitos / notas importantes:
// - Modelos de face-api.js: define FACE_MODEL_URL apuntando a la carpeta donde
//   hayas alojado los pesos (shards .json/.bin), por ejemplo una carpeta en el
//   bucket 'profile-photos/models' con CORS habilitado. Pesos necesarios:
//   ssdMobilenetv1 + faceLandmark68Net + faceRecognitionNet.
// - Depende de @tensorflow/tfjs (backend cpu/wasm) y @napi-rs/canvas para
//   decodificar las imágenes. El backend de canvas/tfjs puede requerir ajustes
//   según el runtime de Deno de Supabase.
// - NO probado en entorno local; es un scaffold que debe validarse al desplegar.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import * as faceapi from "npm:face-api.js@0.22.2";
import * as tf from "npm:@tensorflow/tfjs@4.22.0";
import { createCanvas, loadImage } from "npm:@napi-rs/canvas@0.1.0";

const THRESHOLD = 0.6; // distancia euclídea máxima para ser la misma persona

async function cargarModelos(modelUrl: string) {
  await faceapi.nets.ssdMobilenetv1.loadFromUri(modelUrl);
  await faceapi.nets.faceLandmark68Net.loadFromUri(modelUrl);
  await faceapi.nets.faceRecognitionNet.loadFromUri(modelUrl);
}

async function descriptorDesdeUrl(url: string): Promise<number[] | null> {
  const res = await fetch(url);
  if (!res.ok) return null;
  const buf = await res.arrayBuffer();
  const img = await loadImage(new Uint8Array(buf));
  const canvas = createCanvas(img.width, img.height);
  const ctx = canvas.getContext("2d");
  ctx.drawImage(img as unknown as CanvasImageSource, 0, 0);
  const deteccion = await faceapi
    .detectSingleFace(
      canvas as unknown as faceapi.ITypedImage,
      new faceapi.SsdMobilenetv1Options(),
    )
    .withFaceLandmarks()
    .withFaceDescriptor();
  return deteccion ? Array.from(deteccion.descriptor) : null;
}

function distancia(a: number[], b: number[]): number {
  let suma = 0;
  for (let i = 0; i < a.length; i++) suma += (a[i] - b[i]) ** 2;
  return Math.sqrt(suma);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Método no permitido", { status: 405 });
  }

  const body = await req.json().catch(() => ({})) as {
    selfie?: string;
    fotos?: string[];
  };
  if (!body.selfie || !body.fotos || body.fotos.length === 0) {
    return new Response(
      JSON.stringify({ coincide: false, motivo: "faltan_datos" }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }

  try {
    await tf.setBackend("cpu");
    await tf.ready();

    const modelUrl =
      Deno.env.get("FACE_MODEL_URL") ?? "https://<tu-host>/models";
    await cargarModelos(modelUrl);

    const selfieDesc = await descriptorDesdeUrl(body.selfie);
    if (!selfieDesc) {
      return new Response(
        JSON.stringify({ coincide: false, motivo: "sin_rostro_selfie" }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }

    for (const foto of body.fotos) {
      const desc = await descriptorDesdeUrl(foto);
      if (desc && distancia(selfieDesc, desc) < THRESHOLD) {
        return new Response(JSON.stringify({ coincide: true }), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({ coincide: false }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ coincide: false, error: String(e) }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }
});
