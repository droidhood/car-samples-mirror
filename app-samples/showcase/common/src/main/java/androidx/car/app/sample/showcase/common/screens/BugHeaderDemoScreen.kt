package androidx.car.app.sample.showcase.common.screens

import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Header
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.sample.showcase.common.R
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch

class BugHeaderDemoScreen(carContext: CarContext): Screen(carContext) {
    private var isLoading = true
    private var rows = mutableListOf<Row>()

    init {
        (1..5).map { index ->
            rows.add(Row.Builder().setTitle("Row $index").build())
        }

        MainScope().launch {
            flow {
                delay(1000)
                emit(Unit)
            }.collect {
                isLoading = false
                invalidate()
            }
        }
    }

    override fun onGetTemplate(): Template {
        val headerBuilder = Header.Builder()
            .setTitle(carContext.getString(R.string.bug_screen_title))
            .setStartHeaderAction(Action.BACK)
            //.addEndHeaderAction(getAction())
        val listBuilder = ListTemplate.Builder()
            .setLoading(isLoading)

        if (!isLoading) {
            val itemListBuilder = ItemList.Builder()
            rows.forEach {
                itemListBuilder.addItem(it)
            }
            listBuilder.setSingleList(itemListBuilder.build())
            headerBuilder.addEndHeaderAction(getAction())
        }
        listBuilder.setHeader(headerBuilder.build())

        return listBuilder.build()
    }

    private fun getAction(): Action {
        return Action.Builder()
            .setTitle("Navigate")
            .setOnClickListener {
                CarToast.makeText(carContext, "Action clicked", CarToast.LENGTH_LONG).show()
            }
            .build()
    }
}