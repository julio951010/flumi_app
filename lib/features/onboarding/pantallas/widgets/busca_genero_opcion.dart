import 'package:flutter/material.dart';
import '../../../perfiles/perfil_etiquetas.dart';
import 'tarjeta_opcion_check.dart';

typedef BuscaGeneroCallback = void Function(Set<String> seleccionados);

class BuscaGeneroOpcion extends StatelessWidget {
  final Set<String> seleccionados;
  final BuscaGeneroCallback onCambio;

  const BuscaGeneroOpcion({
    super.key,
    required this.seleccionados,
    required this.onCambio,
  });

  static const List<String> codigosGeneros = [
    'hombres',
    'mujeres',
    'no_binarias',
  ];
  static const String codigoTodos = 'todos';
  static const String codigoPrefieroNoDecir = 'prefiero_no_decirlo';

  void _alternar(String codigo, Set<String> actual) {
    final nuevo = Set<String>.from(actual);

    if (codigo == codigoPrefieroNoDecir) {
      nuevo
        ..clear()
        ..add(codigo);
    } else {
      nuevo.remove(codigoPrefieroNoDecir);

      if (codigo == codigoTodos) {
        if (nuevo.contains(codigoTodos)) {
          nuevo.remove(codigoTodos);
          nuevo.removeAll(codigosGeneros);
        } else {
          nuevo.add(codigoTodos);
          nuevo.addAll(codigosGeneros);
        }
      } else {
        if (nuevo.contains(codigo)) {
          nuevo.remove(codigo);
        } else {
          nuevo.add(codigo);
        }

        final todos = codigosGeneros.every(nuevo.contains);
        if (todos) {
          nuevo.add(codigoTodos);
        } else {
          nuevo.remove(codigoTodos);
        }
      }
    }

    onCambio(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final opcion in opcionesBuscaGenero) ...[
            TarjetaOpcionCheck(
              etiqueta: opcion.$1,
              seleccionada: seleccionados.contains(opcion.$2),
              onTap: () => _alternar(opcion.$2, seleccionados),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}