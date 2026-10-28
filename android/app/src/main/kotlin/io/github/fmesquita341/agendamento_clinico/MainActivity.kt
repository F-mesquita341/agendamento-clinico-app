package io.github.fmesquita341.agendamento_clinico

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        criarCanalDosLembretes()
    }

    /**
     * O canal em que o FCM mostra o lembrete de consulta: o manifesto o aponta
     * como o padrão, porque a API não manda canal. Importância alta, para o
     * aviso aparecer no topo da tela, e não só na bandeja. Criar de novo um
     * canal que já existe não muda nada: depois de criado, só a pessoa muda a
     * importância, nas configurações do Android.
     */
    private fun criarCanalDosLembretes() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(CANAL_DOS_LEMBRETES, "Lembretes de consulta", NotificationManager.IMPORTANCE_HIGH)
        canal.description = "Um aviso antes de cada consulta confirmada."
        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }

    private companion object {
        /** O mesmo do manifesto, em default_notification_channel_id. */
        const val CANAL_DOS_LEMBRETES = "lembretes"
    }
}
