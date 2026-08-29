import 'package:flutter_test/flutter_test.dart';
import 'package:Flumi/core/base_datos_local/database.dart';
import 'package:Flumi/features/encuentros/pantallas/filtros_encuentros_sheet.dart';
import 'package:Flumi/features/perfiles/perfil_etiquetas.dart';

void main() {
  Usuario _usuario({String educacion = '', String trabajo = ''}) {
    return Usuario(
      uuid: 'u1',
      nombre: 'Test',
      edad: 25,
      biografia: '',
      fotosLocalesRutas: const [],
      fotosUrls: const [],
      preferenciaEdadMin: 18,
      preferenciaEdadMax: 60,
      genero: 'mujer',
      buscaGenero: 'hombre',
      queBusca: 'relacion',
      ciudad: 'La Habana',
      ubicacionLat: 23.1,
      ubicacionLon: -82.3,
      verificadoStatus: true,
      scorePopularidad: 0,
      pendienteDeSincronizar: false,
      esPerfilPropio: false,
      perfilCompletado: true,
      orientacionSexual: 'bisexual',
      situacionSentimental: 'soltero',
      intereses: const [],
      altura: '170',
      educacion: educacion,
      trabajo: trabajo,
      profesion: '',
      preferenciaRelacion: '',
      bebe: 'no_bebo',
      fuma: 'no_fumo',
      hijos: 'no_quiero',
      personalidad: '',
      signoZodiaco: '',
      mascotas: 'no_tengo',
      religion: 'catolica',
      idiomas: 'Español',
      tatuajes: 'no_tengo',
      preguntasPerfil: const [],
      fotoVerificacion: '',
      ultimaConexion: null,
      ocultarEnLinea: false,
      ocultarEdad: false,
      ocultarPerfil: false,
      ocultarVisitas: false,
      creadoEn: DateTime(2025),
    );
  }

  test('filtro de orientación matchea al usuario', () {
    final u = _usuario();
    final filtros = FiltrosEncuentros(
      avanzado: {'orientacion': [opcionesOrientacionSexual[3].$1]},
    );
    expect(cumpleFiltrosAvanzados(filtros, u), isTrue);
  });

  test('filtro de orientación descarta al usuario', () {
    final u = _usuario();
    final filtros = FiltrosEncuentros(
      avanzado: {'orientacion': [opcionesOrientacionSexual[0].$1]},
    );
    expect(cumpleFiltrosAvanzados(filtros, u), isFalse);
  });

  test('filtro de educación matchea valor legado', () {
    final u = _usuario(educacion: 'superior');
    final filtros = FiltrosEncuentros(
      avanzado: {'educacion': [opcionesEducacion[4].$1]},
    );
    expect(cumpleFiltrosAvanzados(filtros, u), isTrue);
  });

  test('filtro de trabajo matchea valor legado', () {
    final u = _usuario(trabajo: 'independiente');
    final filtros = FiltrosEncuentros(
      avanzado: {'trabajo': [opcionesTrabajo[2].$1]},
    );
    expect(cumpleFiltrosAvanzados(filtros, u), isTrue);
  });

  test('sin filtros avanzados acepta a todos', () {
    final u = _usuario();
    expect(cumpleFiltrosAvanzados(FiltrosEncuentros(), u), isTrue);
  });
}