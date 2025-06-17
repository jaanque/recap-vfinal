import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isUploading = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 15;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0], // Usar la cámara trasera por defecto
          ResolutionPreset.high,
          enableAudio: true,
        );
        
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      print('Error inicializando cámara: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar la cámara: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      // Iniciar el temporizador
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });

        // Detener automáticamente después de 15 segundos
        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      print('Error iniciando grabación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar grabación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    try {
      _recordingTimer?.cancel();
      final XFile videoFile = await _controller!.stopVideoRecording();
      
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });

      // Mostrar diálogo de confirmación
      _showUploadDialog(videoFile);
    } catch (e) {
      print('Error deteniendo grabación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al detener grabación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUploadDialog(XFile videoFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Video grabado'),
          content: const Text('¿Deseas subir el video a Supabase Storage?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Eliminar el archivo temporal
                File(videoFile.path).delete();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadVideo(videoFile);
              },
              child: const Text('Subir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadVideo(XFile videoFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Crear un nombre único para el archivo
      final String fileName = 'video_${user.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Leer el archivo como bytes
      final File file = File(videoFile.path);
      final List<int> bytes = await file.readAsBytes();

      // Subir a Supabase Storage
      final String path = await Supabase.instance.client.storage
          .from('videos')
          .uploadBinary(fileName, bytes);

      // Insertar registro en la tabla videos
      await Supabase.instance.client.from('videos').insert({
        'user_id': user.id,
        'file_name': fileName,
        'file_path': path,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Eliminar archivo temporal
      await file.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Video subido exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error subiendo video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentCameraIndex = _cameras!.indexOf(_controller!.description);
    final newCameraIndex = (currentCameraIndex + 1) % _cameras!.length;

    await _controller?.dispose();
    
    _controller = CameraController(
      _cameras![newCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error cambiando cámara: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Grabar Video',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Vista previa de la cámara
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // Overlay con controles
          Positioned.fill(
            child: Column(
              children: [
                // Indicador de grabación y temporizador
                if (_isRecording)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REC ${_formatTime(_recordingSeconds)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const Spacer(),
                
                // Controles inferiores
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón cambiar cámara
                      if (_cameras != null && _cameras!.length > 1)
                        IconButton(
                          onPressed: _isRecording ? null : _switchCamera,
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                      
                      // Botón grabar/detener
                      GestureDetector(
                        onTap: _isUploading 
                            ? null 
                            : (_isRecording ? _stopRecording : _startRecording),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red : Colors.white,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: _isUploading
                              ? const CircularProgressIndicator(
                                  color: Colors.red,
                                  strokeWidth: 3,
                                )
                              : Icon(
                                  _isRecording ? Icons.stop : Icons.videocam,
                                  color: _isRecording ? Colors.white : Colors.red,
                                  size: 32,
                                ),
                        ),
                      ),
                      
                      // Espacio para simetría
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Indicador de carga
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Subiendo video...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}