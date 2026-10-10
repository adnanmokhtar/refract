package com.pantrygo.picker

import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.pantrygo.picker.databinding.ActivityWeighBatchBinding

/**
 * The scale vendor's batch screen: the picker weighs every loose-produce line of an order in one go, and the
 * readings are only sent when Save is tapped. Leaving with unsaved readings asks first.
 */
class WeighBatchActivity : AppCompatActivity() {
  private lateinit var binding: ActivityWeighBatchBinding
  private val readings = mutableListOf<Int>()

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    binding = ActivityWeighBatchBinding.inflate(layoutInflater)
    setContentView(binding.root)
    binding.save.setOnClickListener { saveAndFinish() }
  }

  @Deprecated("Deprecated in Java")
  override fun onBackPressed() {
    if (readings.isNotEmpty()) {
      AlertDialog.Builder(this)
        .setMessage(R.string.discard_readings)
        .setPositiveButton(R.string.discard) { _, _ -> finish() }
        .setNegativeButton(R.string.keep_weighing, null)
        .show()
    } else {
      super.onBackPressed()
    }
  }

  private fun saveAndFinish() {
    setResult(RESULT_OK, intent.putExtra("grams", readings.toIntArray()))
    finish()
  }
}
